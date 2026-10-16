import 'package:ai_legal_assistant/core/database/app_database.dart';
import 'package:ai_legal_assistant/features/library/document_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('SQLite records and lexical retrieval', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute(
      'CREATE TABLE notes (id INTEGER PRIMARY KEY, title TEXT, body TEXT)',
    );
    await db.execute(
      'CREATE TABLE documents (id INTEGER PRIMARY KEY, name TEXT)',
    );
    await db.execute(
      'CREATE TABLE document_chunks (id INTEGER PRIMARY KEY, document_id INTEGER, position INTEGER, text TEXT, page_number INTEGER)',
    );
    final store = AppDatabase.testing(db);
    await store.insert('notes', {
      'title': 'Cell biology',
      'body': 'Mitosis has phases.',
    });
    await store.insert('documents', {'id': 1, 'name': 'Biology.txt'});
    await store.insert('document_chunks', {
      'document_id': 1,
      'position': 0,
      'text': 'Mitosis divides one cell into two daughter cells.',
      'page_number': null,
    });
    await store.insert('document_chunks', {
      'document_id': 1,
      'position': 1,
      'text': 'Photosynthesis uses sunlight.',
      'page_number': null,
    });
    expect((await store.list('notes')).single['title'], 'Cell biology');
    final result = await DocumentService(
      store,
    ).retrieve('What happens during mitosis?', [1]);
    expect(result.length, 1);
    expect(result.single['position'], 0);
    await db.close();
  });

  test('version 2 migration keeps messages and adds action payload', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute(
      'CREATE TABLE messages (id INTEGER PRIMARY KEY, content TEXT NOT NULL)',
    );
    await db.insert('messages', {'content': 'Saved conversation'});
    await AppDatabase.migrate(db, 2);
    final rows = await db.query('messages');
    expect(rows.single['content'], 'Saved conversation');
    expect(rows.single.containsKey('action_json'), isTrue);
    await db.close();
  });
}
