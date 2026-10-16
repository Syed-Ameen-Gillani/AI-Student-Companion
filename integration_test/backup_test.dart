import 'dart:io';
import 'package:ai_legal_assistant/core/database/app_database.dart';
import 'package:ai_legal_assistant/core/database/backup_service.dart';
import 'package:ai_legal_assistant/features/library/document_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('backup survives reset and corrupt backup preserves data', (
    tester,
  ) async {
    final store = await AppDatabase.open();
    final documentService = DocumentService(store);
    final backupService = BackupService(store);
    final source = File(
      p.join((await getTemporaryDirectory()).path, 'backup-smoke.txt'),
    );
    await source.writeAsString(
      'Cell division has mitosis and cytokinesis.',
      flush: true,
    );
    final marker = DateTime.now().microsecondsSinceEpoch.toString();
    final noteId = await store.insert('notes', {
      'title': 'Backup note $marker',
      'body': 'Restore this body',
      'subject': 'Biology',
      'tags': 'test',
      'pinned': 0,
      'created_at': store.now,
      'updated_at': store.now,
    });
    final docId = await documentService.importFile(
      source,
      'backup-smoke-$marker.txt',
    );
    try {
      final archive = await backupService.createArchive();
      final prepared = backupService.prepare(archive);
      final counts = <String, int>{};
      for (final table in BackupService.tables) {
        counts[table] = (await store.list(table)).length;
      }
      final oldDocs = await store.list('documents');
      await store.db.transaction((txn) async {
        for (final table in [
          'conversations',
          'notes',
          'tasks',
          'documents',
          'settings',
        ]) {
          await txn.delete(table);
        }
      });
      for (final doc in oldDocs) {
        final file = File(doc['local_path'] as String);
        if (await file.exists()) await file.delete();
      }
      expect(await store.list('notes'), isEmpty);
      await backupService.restore(
        prepared,
        Directory(
          p.join((await getApplicationDocumentsDirectory()).path, 'imports'),
        ),
      );
      for (final table in BackupService.tables) {
        expect((await store.list(table)).length, counts[table], reason: table);
      }
      expect(
        (await store.list(
          'notes',
          where: 'id = ?',
          args: [noteId],
        )).single['body'],
        'Restore this body',
      );
      final restoredDoc = (await store.list(
        'documents',
        where: 'id = ?',
        args: [docId],
      )).single;
      expect(await File(restoredDoc['local_path'] as String).exists(), isTrue);
      expect(await documentService.retrieve('mitosis', [docId]), isNotEmpty);

      expect(() => backupService.prepare([1, 2, 3, 4]), throwsException);
      expect(
        (await store.list(
          'notes',
          where: 'id = ?',
          args: [noteId],
        )).single['body'],
        'Restore this body',
      );
    } finally {
      await store.delete('notes', noteId);
      final docs = await store.list(
        'documents',
        where: 'id = ?',
        args: [docId],
      );
      if (docs.isNotEmpty) await documentService.remove(docs.single);
      if (await source.exists()) await source.delete();
      await store.db.close();
    }
  });
}
