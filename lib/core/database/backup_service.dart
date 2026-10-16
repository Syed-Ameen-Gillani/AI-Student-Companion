import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'app_database.dart';

class PreparedBackup {
  PreparedBackup(this.tables, this.files);
  final Map<String, List<Map<String, Object?>>> tables;
  final Map<String, List<int>> files;
}

class BackupService {
  BackupService(this.store);
  final StudyRepository store;
  static const version = 3;
  static const maxBytes = 80 * 1024 * 1024;
  static const tables = [
    'conversations',
    'messages',
    'notes',
    'tasks',
    'documents',
    'document_chunks',
    'message_sources',
    'conversation_documents',
    'settings',
  ];

  Future<List<int>> createArchive() async {
    final records = <String, dynamic>{};
    for (final table in tables) {
      records[table] = await store.db.query(table);
    }
    records['settings'] = (records['settings'] as List<Map<String, Object?>>)
        .where((row) => row['key'] != 'gemini_api_key')
        .toList();
    final files = <String, String>{};
    for (final doc in records['documents'] as List<Map<String, Object?>>) {
      final file = File(doc['local_path'] as String);
      if (!await file.exists()) {
        throw FormatException('Missing imported document: ${doc['name']}');
      }
      final bytes = await file.readAsBytes();
      if (sha256.convert(bytes).toString() != doc['hash']) {
        throw FormatException('Imported document changed: ${doc['name']}');
      }
      files['${doc['id']}'] = base64Encode(bytes);
    }
    final archive = Archive()
      ..addFile(
        ArchiveFile.string(
          'backup.json',
          jsonEncode({'version': version, 'tables': records, 'files': files}),
        ),
      );
    return ZipEncoder().encode(archive);
  }

  PreparedBackup prepare(List<int> bytes) {
    if (bytes.length > maxBytes) {
      throw const FormatException('Backup is too large.');
    }
    final archive = ZipDecoder().decodeBytes(bytes);
    final entries = archive.files
        .where((file) => file.name == 'backup.json')
        .toList();
    if (entries.length != 1) {
      throw const FormatException('Not a Student Companion backup.');
    }
    final content = entries.single.content;
    if (content.length > maxBytes) {
      throw const FormatException('Backup contents are too large.');
    }
    final data = jsonDecode(utf8.decode(content));
    if (data is! Map ||
        ![1, 2, 3].contains(data['version']) ||
        data['tables'] is! Map ||
        data['files'] is! Map) {
      throw const FormatException('Backup structure is invalid.');
    }
    final rawTables = data['tables'] as Map;
    if (data['version'] == 1) rawTables['conversation_documents'] = [];
    final parsedTables = <String, List<Map<String, Object?>>>{};
    for (final name in tables) {
      final rows = rawTables[name];
      if (rows is! List || rows.any((row) => row is! Map)) {
        throw FormatException('Invalid $name data.');
      }
      parsedTables[name] = [
        for (final row in rows) Map<String, Object?>.from(row as Map),
      ];
    }
    final rawFiles = data['files'] as Map;
    final decoded = <String, List<int>>{};
    var total = 0;
    for (final entry in rawFiles.entries) {
      if (entry.key is! String || entry.value is! String) {
        throw const FormatException('Invalid file entry.');
      }
      final fileBytes = base64Decode(entry.value as String);
      total += fileBytes.length;
      if (total > maxBytes) {
        throw const FormatException('Backup contents are too large.');
      }
      decoded[entry.key as String] = fileBytes;
    }
    for (final doc in parsedTables['documents']!) {
      final id = doc['id'];
      final format = doc['format'];
      final fileBytes = decoded['$id'];
      if (id is! int ||
          format is! String ||
          !{'pdf', 'txt'}.contains(format) ||
          fileBytes == null ||
          doc['hash'] != sha256.convert(fileBytes).toString()) {
        throw const FormatException('A document file is missing or invalid.');
      }
    }
    return PreparedBackup(parsedTables, decoded);
  }

  Future<void> restore(
    PreparedBackup backup,
    Directory importsDirectory,
  ) async {
    await importsDirectory.create(recursive: true);
    final staged = <File>[];
    var committed = false;
    try {
      final oldDocuments = await store.list('documents');
      final restoreId = DateTime.now().microsecondsSinceEpoch;
      for (final doc in backup.tables['documents']!) {
        final id = doc['id'] as int;
        final path = p.join(
          importsDirectory.path,
          'restored_${restoreId}_$id.${doc['format']}',
        );
        final file = File(path);
        await file.writeAsBytes(backup.files['$id']!, flush: true);
        staged.add(file);
        doc['local_path'] = path;
      }
      await store.db.transaction((txn) async {
        for (final table in [
          'message_sources',
          'conversation_documents',
          'messages',
          'document_chunks',
          'documents',
          'conversations',
          'notes',
          'tasks',
          'settings',
        ]) {
          await txn.delete(table);
        }
        for (final table in [
          'conversations',
          'notes',
          'tasks',
          'documents',
          'messages',
          'document_chunks',
          'message_sources',
          'conversation_documents',
          'settings',
        ]) {
          for (final row in backup.tables[table]!) {
            await txn.insert(table, row);
          }
        }
      });
      committed = true;
      for (final doc in oldDocuments) {
        final file = File(doc['local_path'] as String);
        if (await file.exists()) {
          try {
            await file.delete();
          } catch (_) {
            /* New data is committed. */
          }
        }
      }
    } finally {
      if (!committed) {
        for (final file in staged) {
          if (await file.exists()) await file.delete();
        }
      }
    }
  }
}
