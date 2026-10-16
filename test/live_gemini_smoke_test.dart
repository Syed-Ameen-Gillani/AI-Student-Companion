import 'dart:io';
import 'package:ai_legal_assistant/core/network/gemini_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'live Gemini request returns a nonempty answer',
    () async {
      final lines = await File('.env').readAsLines();
      final keyLine = lines.firstWhere((line) => line.startsWith('GEMINI_API_KEY='));
      final key = keyLine.substring('GEMINI_API_KEY='.length).trim().replaceAll(RegExp(r'''^["']|["']$'''), '');
      expect(key, isNotEmpty);
      final service = GeminiService(
        const FlutterSecureStorage(),
        readKeyForTest: () async => key,
      );
      try {
        final answer = await service.generate(prompt: 'Reply with OK only.');
        expect(answer.trim(), isNotEmpty);
      } finally {
        service.client.close();
      }
    },
    skip: !const bool.fromEnvironment('LIVE_GEMINI'),
  );
}
