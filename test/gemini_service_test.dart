import 'dart:convert';
import 'package:ai_legal_assistant/core/network/gemini_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'Gemini client sends bounded history and requests JSON when needed',
    () async {
      final client = MockClient((request) async {
        expect(
          request.url.path,
        '/v1beta/models/gemini-3.5-flash-lite:generateContent',
        );
        expect(request.headers['x-goog-api-key'], 'test-key');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect((body['contents'] as List).length, 13);
        expect(
          body['generationConfig']['responseMimeType'],
          'application/json',
        );
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': '{"action":"reply","message":"Hello"}'},
                  ],
                },
              },
            ],
          }),
          200,
        );
      });
      final service = GeminiService(
        const FlutterSecureStorage(),
        client: client,
        readKeyForTest: () async => 'test-key',
      );
      final answer = await service.generate(
        prompt: 'Help me study',
        jsonResponse: true,
        history: List.generate(
          20,
          (i) => {'role': 'user', 'content': 'Question $i'},
        ),
      );
      expect(answer, contains('Hello'));
      client.close();
    },
  );

  test('Gemini quota errors are actionable', () async {
    final client = MockClient((_) async => http.Response('{}', 429));
    final service = GeminiService(
      const FlutterSecureStorage(),
      client: client,
      readKeyForTest: () async => 'test-key',
    );
    expect(
      () => service.generate(prompt: 'Question'),
      throwsA(
        isA<GeminiException>().having(
          (e) => e.message,
          'message',
          contains('quota'),
        ),
      ),
    );
    client.close();
  });
}
