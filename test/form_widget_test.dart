import 'package:ai_legal_assistant/core/database/app_database.dart';
import 'package:ai_legal_assistant/features/tasks/tasks_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  setUpAll(() async {
    sqfliteFfiInit();
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute(
      'CREATE TABLE tasks (id INTEGER PRIMARY KEY, title TEXT, description TEXT, subject TEXT, category TEXT, priority TEXT, due_at TEXT, has_time INTEGER, status TEXT, created_at TEXT, updated_at TEXT)',
    );
  });
  tearDownAll(() async => db.close());

  testWidgets('task draft requires explicit Save and a title', (tester) async {
    final store = AppDatabase.testing(db);
    await tester.pumpWidget(
      MaterialApp(
        home: TaskEditor(store: store, draft: const {'title': ''}),
      ),
    );
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Add a title.'), findsOneWidget);
    expect(await tester.runAsync(() => store.list('tasks')), isEmpty);
  });
}
