import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

abstract interface class StudyRepository {
  Database get db;
  String get now;
  Future<List<Map<String, Object?>>> list(
    String table, {
    String? where,
    List<Object?>? args,
    String? orderBy,
  });
  Future<int> insert(String table, Map<String, Object?> values);
  Future<int> update(String table, int id, Map<String, Object?> values);
  Future<int> delete(String table, int id);
  Future<String?> setting(String key);
  Future<void> setSetting(String key, String value);
}

class AppDatabase implements StudyRepository {
  AppDatabase._(this.db);
  AppDatabase.testing(this.db);
  @override
  final Database db;

  static Future<AppDatabase> open() async {
    final path = p.join(await getDatabasesPath(), 'assistant.db');
    final db = await openDatabase(
      path,
      version: 3,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE conversations (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE messages (id INTEGER PRIMARY KEY AUTOINCREMENT, conversation_id INTEGER NOT NULL REFERENCES conversations(id) ON DELETE CASCADE, role TEXT NOT NULL, content TEXT NOT NULL, status TEXT NOT NULL, created_at TEXT NOT NULL, action_json TEXT)',
        );
        await db.execute(
          'CREATE TABLE notes (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, body TEXT NOT NULL, subject TEXT NOT NULL DEFAULT "", tags TEXT NOT NULL DEFAULT "", pinned INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL, updated_at TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE tasks (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, description TEXT NOT NULL DEFAULT "", category TEXT NOT NULL DEFAULT "general", subject TEXT NOT NULL DEFAULT "", due_at TEXT, has_time INTEGER NOT NULL DEFAULT 0, priority TEXT NOT NULL DEFAULT "normal", status TEXT NOT NULL DEFAULT "open", created_at TEXT NOT NULL, updated_at TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE documents (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, local_path TEXT NOT NULL, format TEXT NOT NULL, hash TEXT NOT NULL, extraction_status TEXT NOT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE document_chunks (id INTEGER PRIMARY KEY AUTOINCREMENT, document_id INTEGER NOT NULL REFERENCES documents(id) ON DELETE CASCADE, position INTEGER NOT NULL, text TEXT NOT NULL, page_number INTEGER)',
        );
        await db.execute(
          'CREATE TABLE message_sources (message_id INTEGER NOT NULL REFERENCES messages(id) ON DELETE CASCADE, document_id INTEGER NOT NULL REFERENCES documents(id) ON DELETE CASCADE, chunk_id INTEGER NOT NULL REFERENCES document_chunks(id) ON DELETE CASCADE, PRIMARY KEY(message_id, chunk_id))',
        );
        await db.execute(
          'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE INDEX chunks_document ON document_chunks(document_id)',
        );
        await db.execute(
          'CREATE INDEX messages_conversation ON messages(conversation_id)',
        );
        await db.execute('CREATE INDEX tasks_due ON tasks(due_at)');
        await db.execute(
          'CREATE TABLE conversation_documents (conversation_id INTEGER NOT NULL REFERENCES conversations(id) ON DELETE CASCADE, document_id INTEGER NOT NULL REFERENCES documents(id) ON DELETE CASCADE, PRIMARY KEY(conversation_id, document_id))',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) => migrate(db, oldVersion),
    );
    return AppDatabase._(db);
  }

  static Future<void> migrate(DatabaseExecutor db, int oldVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'CREATE TABLE conversation_documents (conversation_id INTEGER NOT NULL REFERENCES conversations(id) ON DELETE CASCADE, document_id INTEGER NOT NULL REFERENCES documents(id) ON DELETE CASCADE, PRIMARY KEY(conversation_id, document_id))',
      );
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE messages ADD COLUMN action_json TEXT');
    }
  }

  @override
  String get now => DateTime.now().toUtc().toIso8601String();

  @override
  Future<List<Map<String, Object?>>> list(
    String table, {
    String? where,
    List<Object?>? args,
    String? orderBy,
  }) => db.query(table, where: where, whereArgs: args, orderBy: orderBy);

  @override
  Future<int> insert(String table, Map<String, Object?> values) =>
      db.insert(table, values);
  @override
  Future<int> update(String table, int id, Map<String, Object?> values) =>
      db.update(table, values, where: 'id = ?', whereArgs: [id]);
  @override
  Future<int> delete(String table, int id) =>
      db.delete(table, where: 'id = ?', whereArgs: [id]);

  @override
  Future<String?> setting(String key) async {
    final rows = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  @override
  Future<void> setSetting(String key, String value) async {
    await db.insert('settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
