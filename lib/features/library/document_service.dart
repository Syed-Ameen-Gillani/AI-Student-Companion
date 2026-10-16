import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import '../../core/database/app_database.dart';

class DocumentService {
  DocumentService(this.store);
  final StudyRepository store;
  static const maxFileBytes = 10 * 1024 * 1024;
  static const maxTextCharacters = 500000;

  Future<int?> pickAndImport() async {
    final item = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt'],
    );
    if (item == null) return null;
    final source = item.path == null ? null : File(item.path!);
    if (source == null) {
      throw const FormatException('The selected file could not be read.');
    }
    return importFile(source, item.name);
  }

  Future<int> importFile(File source, String name) async {
    final extension = p.extension(name).toLowerCase();
    if (extension != '.pdf' && extension != '.txt') {
      throw const FormatException(
        'Only text PDFs and TXT files are supported.',
      );
    }
    if (!await source.exists()) {
      throw const FormatException('The selected file could not be read.');
    }
    final bytes = await source.readAsBytes();
    if (bytes.length > maxFileBytes) {
      throw const FormatException('The file exceeds the 10 MB limit.');
    }
    final hash = sha256.convert(bytes).toString();
    final duplicate = await store.list(
      'documents',
      where: 'hash = ?',
      args: [hash],
    );
    if (duplicate.isNotEmpty) {
      throw const FormatException('This document has already been imported.');
    }
    final directory = Directory(
      p.join((await getApplicationDocumentsDirectory()).path, 'imports'),
    );
    await directory.create(recursive: true);
    final target = File(
      p.join(
        directory.path,
        '${DateTime.now().microsecondsSinceEpoch}$extension',
      ),
    );
    await target.writeAsBytes(bytes, flush: true);
    try {
      final pages = <(String, int?)>[];
      if (extension == '.txt') {
        pages.add((await target.readAsString(), null));
      } else {
        final pdf = await PdfDocument.openFile(target.path);
        try {
          for (var i = 0; i < pdf.pages.length; i++) {
            pages.add(((await pdf.pages[i].loadText())?.fullText ?? '', i + 1));
          }
        } finally {
          await pdf.dispose();
        }
      }
      final total = pages.fold<int>(0, (sum, page) => sum + page.$1.length);
      if (total == 0) {
        throw const FormatException(
          'No selectable text was found. Scanned PDFs need OCR, which this app does not provide.',
        );
      }
      if (total > maxTextCharacters) {
        throw const FormatException(
          'Extracted text exceeds the 500,000 character limit.',
        );
      }
      final now = store.now;
      final id = await store.db.transaction((txn) async {
        final id = await txn.insert('documents', {
          'name': name,
          'local_path': target.path,
          'format': extension.substring(1),
          'hash': hash,
          'extraction_status': 'ready',
          'created_at': now,
          'updated_at': now,
        });
        var position = 0;
        for (final page in pages) {
          for (final chunk in chunkText(page.$1)) {
            await txn.insert('document_chunks', {
              'document_id': id,
              'position': position++,
              'text': chunk,
              'page_number': page.$2,
            });
          }
        }
        return id;
      });
      return id;
    } catch (_) {
      await target.delete();
      rethrow;
    }
  }

  static List<String> chunkText(
    String text, {
    int size = 1200,
    int overlap = 180,
  }) {
    final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.isEmpty) return [];
    final chunks = <String>[];
    var start = 0;
    while (start < clean.length) {
      var end = (start + size).clamp(0, clean.length);
      if (end < clean.length) {
        final space = clean.lastIndexOf(' ', end);
        if (space > start + size ~/ 2) end = space;
      }
      chunks.add(clean.substring(start, end));
      if (end == clean.length) break;
      start = (end - overlap).clamp(start + 1, clean.length);
    }
    return chunks;
  }

  Future<List<Map<String, Object?>>> retrieve(
    String question,
    List<int> documentIds, {
    int limit = 5,
  }) async {
    if (documentIds.isEmpty) return [];
    final terms = RegExp(
      r'[a-zA-Z0-9]{3,}',
    ).allMatches(question.toLowerCase()).map((m) => m.group(0)!).toSet();
    if (terms.isEmpty) return [];
    final placeholders = List.filled(documentIds.length, '?').join(',');
    final rows = await store.db.rawQuery('''
      SELECT c.*, d.name AS document_name FROM document_chunks c
      JOIN documents d ON d.id = c.document_id
      WHERE c.document_id IN ($placeholders)
    ''', documentIds);
    final ranked = <(int, Map<String, Object?>)>[];
    for (final row in rows) {
      final lower = (row['text'] as String).toLowerCase();
      final score = terms.fold<int>(
        0,
        (sum, term) =>
            sum +
            RegExp('\\b${RegExp.escape(term)}\\b').allMatches(lower).length,
      );
      if (score > 0) ranked.add((score, row));
    }
    ranked.sort((a, b) => b.$1.compareTo(a.$1));
    return ranked.take(limit).map((item) => item.$2).toList();
  }

  Future<void> remove(Map<String, Object?> document) async {
    await store.delete('documents', document['id'] as int);
    final file = File(document['local_path'] as String);
    if (await file.exists()) await file.delete();
  }
}
