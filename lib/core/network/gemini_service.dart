import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class GeminiException implements Exception {
  const GeminiException(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract interface class AiService {
  Future<bool> get hasKey;
  Future<void> saveKey(String key);
  Future<void> deleteKey();
  Future<String> generate({
    required String prompt,
    String model = 'gemini-3.5-flash-lite',
    List<Map<String, String>> history = const [],
    bool jsonResponse = false,
  });
}

class GeminiService implements AiService {
  GeminiService(this.storage, {http.Client? client, this.readKeyForTest})
    : client = client ?? http.Client();
  final FlutterSecureStorage storage;
  final http.Client client;
  final Future<String?> Function()? readKeyForTest;
  static const keyName = 'gemini_api_key';
  static const defaultModel = 'gemini-3.5-flash-lite';

  @override
  Future<bool> get hasKey async =>
      (await (readKeyForTest?.call() ?? storage.read(key: keyName)))
          ?.isNotEmpty ==
      true;
  @override
  Future<void> saveKey(String key) =>
      storage.write(key: keyName, value: key.trim());
  @override
  Future<void> deleteKey() => storage.delete(key: keyName);

  @override
  Future<String> generate({
    required String prompt,
    String model = defaultModel,
    List<Map<String, String>> history = const [],
    bool jsonResponse = false,
  }) async {
    final key = await (readKeyForTest?.call() ?? storage.read(key: keyName));
    if (key == null || key.isEmpty) {
      throw const GeminiException(
        'Add a Gemini API key in Settings to use AI.',
      );
    }
    if (!RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(model)) {
      throw const GeminiException('The model ID is invalid.');
    }
    final contents = [
      for (final item in history.take(12))
        {
          'role': item['role'] == 'assistant' ? 'model' : 'user',
          'parts': [
            {'text': item['content'] ?? ''},
          ],
        },
      {
        'role': 'user',
        'parts': [
          {'text': prompt},
        ],
      },
    ];
    try {
      final response = await client
          .post(
            Uri.https(
              'generativelanguage.googleapis.com',
              '/v1beta/models/$model:generateContent',
            ),
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': key,
            },
            body: jsonEncode({
              'contents': contents,
              if (jsonResponse)
                'generationConfig': {'responseMimeType': 'application/json'},
            }),
          )
          .timeout(const Duration(seconds: 45));
      if (response.statusCode != 200) {
        switch (response.statusCode) {
          case 400:
            throw const GeminiException(
              'Gemini rejected the request. Check the model and input.',
            );
          case 401:
          case 403:
            throw const GeminiException(
              'The Gemini key is invalid or lacks access. Check Settings.',
            );
          case 404:
            throw const GeminiException(
              'This Gemini model is unavailable. Choose another model in Settings.',
            );
          case 429:
            throw const GeminiException(
              'Gemini quota or rate limit reached. Try again later.',
            );
          default:
            throw GeminiException(
              'Gemini server error (${response.statusCode}). Try again later.',
            );
        }
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        throw const GeminiException(
          'Gemini returned no answer. The request may have been blocked.',
        );
      }
      final parts = (candidates.first['content']?['parts'] as List?) ?? [];
      final answer = parts.map((part) => part['text'] ?? '').join().trim();
      if (answer.isEmpty) {
        throw const GeminiException(
          'Gemini returned an empty or blocked answer.',
        );
      }
      return answer;
    } on SocketException {
      throw const GeminiException(
        'No internet connection. Your local data is still available.',
      );
    } on TimeoutException {
      throw const GeminiException(
        'Gemini timed out. Retry when the connection improves.',
      );
    } on http.ClientException {
      throw const GeminiException(
        'Could not reach Gemini. Check your connection.',
      );
    }
  }
}
