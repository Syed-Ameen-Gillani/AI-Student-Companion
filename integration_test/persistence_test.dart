import 'package:ai_legal_assistant/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('note and task remain after app widget restart', (tester) async {
    final marker = DateTime.now().millisecondsSinceEpoch;
    final noteTitle = 'Integration note $marker';
    final taskTitle = 'Integration task $marker';

    await tester.pumpWidget(const StudentCompanion());
    await tester.pumpAndSettle();
    if (find.text('Continue').evaluate().isNotEmpty) {
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('Notes').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('New note'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), noteTitle);
    await tester.enterText(
      find.byType(TextField).at(3),
      'Local persistence test body',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text(noteTitle), findsOneWidget);

    await tester.tap(find.text('Tasks').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('New task'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, taskTitle);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text(taskTitle), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(const StudentCompanion());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notes').last);
    await tester.pumpAndSettle();
    expect(find.text(noteTitle), findsOneWidget);
    await tester.tap(find.text('Tasks').last);
    await tester.pumpAndSettle();
    expect(find.text(taskTitle), findsOneWidget);
  });
}
