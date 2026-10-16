import 'dart:convert';
import 'package:ai_legal_assistant/core/database/app_database.dart';
import 'package:ai_legal_assistant/core/network/gemini_service.dart';
import 'package:ai_legal_assistant/features/assistant/assistant_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'assistant draft writes only after Save; invalid action writes no note',
    (tester) async {
      final store = await AppDatabase.open();
      final marker = DateTime.now().microsecondsSinceEpoch.toString();
      final oldChats = (await store.list(
        'conversations',
      )).map((row) => row['id']).toSet();
      var requests = 0;
      final client = MockClient((request) async {
        requests++;
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(
          body['generationConfig']['responseMimeType'],
          'application/json',
        );
        final answer = requests == 1
            ? jsonEncode({
                'action': 'draft_note',
                'title': 'Cell notes $marker',
                'body': 'Mitosis divides cells.',
                'subject': 'Biology',
                'tags': 'cells',
              })
            : '{"action":"delete_note","id":1}';
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': answer},
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
        await tester.tap(find.text('Notes'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextField).last,
          'Save these notes about mitosis',
        );
        await tester.tap(find.byTooltip('Send'));
        await tester.pumpAndSettle();
        expect(
          await store.list(
            'notes',
            where: 'title = ?',
            args: ['Cell notes $marker'],
          ),
          isEmpty,
        );
        expect(find.byTooltip('Review note draft'), findsOneWidget);

        await tester.tap(find.byTooltip('Review note draft'));
        await tester.pumpAndSettle();
        expect(find.text('Cell notes $marker'), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(
          await store.list(
            'notes',
            where: 'title = ?',
            args: ['Cell notes $marker'],
          ),
          isEmpty,
        );

        await tester.tap(find.byTooltip('Review note draft'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(
          (await store.list(
            'notes',
            where: 'title = ?',
            args: ['Cell notes $marker'],
          )).length,
          1,
        );

        await tester.enterText(find.byType(TextField).last, 'Delete my note');
        await tester.tap(find.byTooltip('Send'));
        await tester.pumpAndSettle();
        expect(requests, 2);
        expect(
          (await store.list(
            'notes',
            where: 'title = ?',
            args: ['Cell notes $marker'],
          )).length,
          1,
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        final notes = await store.list(
          'notes',
          where: 'title = ?',
          args: ['Cell notes $marker'],
        );
        for (final note in notes) {
          await store.delete('notes', note['id'] as int);
        }
        final chats = (await store.list(
          'conversations',
        )).where((row) => !oldChats.contains(row['id']));
        for (final chat in chats) {
          await store.delete('conversations', chat['id'] as int);
        }
        client.close();
        await store.db.close();
      }
    },
  );
}
