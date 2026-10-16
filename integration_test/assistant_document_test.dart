import 'dart:convert';
import 'dart:io';
import 'package:ai_legal_assistant/core/database/app_database.dart';
import 'package:ai_legal_assistant/core/network/gemini_service.dart';
import 'package:ai_legal_assistant/features/assistant/assistant_screen.dart';
import 'package:ai_legal_assistant/features/library/document_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'document answer cites stored excerpt and unsupported query stays local',
    (tester) async {
      final store = await AppDatabase.open();
      final service = DocumentService(store);
      final marker = DateTime.now().microsecondsSinceEpoch.toString();
      final source = File(
        p.join((await getTemporaryDirectory()).path, 'biology-$marker.txt'),
      );
      await source.writeAsString(
        'Mitosis divides one cell into two daughter cells. $marker',
        flush: true,
      );
      final docId = await service.importFile(source, 'biology-$marker.txt');
      final before = (await store.list(
        'conversations',
      )).map((row) => row['id']).toSet();
      var requests = 0;
      final client = MockClient((request) async {
        requests++;
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final prompt = body['contents'].last['parts'].first['text'] as String;
        expect(prompt, contains('[S1]'));
        expect(prompt, contains('daughter cells'));
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'Mitosis creates two daughter cells [S1].'},
                  ],
                },
              },
            ],
          }),
          200,
        );
      });
      final gemini = GeminiService(
        const FlutterSecureStorage(),
        client: client,
        readKeyForTest: () async => 'test-key',
      );
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AssistantScreen(
                store: store,
                gemini: gemini,
                revision: 0,
                onChange: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Documents'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Select documents'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('biology-$marker.txt'));
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(TextField).last,
          'What does mitosis create?',
        );
        await tester.tap(find.byTooltip('Send'));
        await tester.pumpAndSettle();
        expect(requests, 1);
        final chats = (await store.list(
          'conversations',
        )).where((row) => !before.contains(row['id'])).toList();
        expect(chats.length, 1);
        final messages = await store.list(
          'messages',
          where: 'conversation_id = ?',
          args: [chats.single['id']],
          orderBy: 'id',
        );
        expect(messages.last['content'], contains('[S1]'));
        final sources = await store.db.query(
          'message_sources',
          where: 'message_id = ?',
          whereArgs: [messages.last['id']],
        );
        expect(sources.single['document_id'], docId);

        await tester.enterText(
          find.byType(TextField).last,
          'quantum chlorophyll?',
        );
        await tester.tap(find.byTooltip('Send'));
        await tester.pumpAndSettle();
        expect(requests, 1);
        final updated = await store.list(
          'messages',
          where: 'conversation_id = ?',
          args: [chats.single['id']],
          orderBy: 'id',
        );
        expect(
          updated.last['content'],
          contains('could not find relevant text'),
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        final chats = (await store.list(
          'conversations',
        )).where((row) => !before.contains(row['id'])).toList();
        for (final chat in chats) {
          await store.delete('conversations', chat['id'] as int);
        }
        final docs = await store.list(
          'documents',
          where: 'id = ?',
          args: [docId],
        );
        if (docs.isNotEmpty) await service.remove(docs.single);
        if (await source.exists()) await source.delete();
        client.close();
        await store.db.close();
      }
    },
  );
}
