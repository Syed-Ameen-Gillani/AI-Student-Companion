import 'dart:convert';
import 'dart:io';
import 'package:ai_legal_assistant/core/database/app_database.dart';
import 'package:ai_legal_assistant/features/library/document_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('text PDF imports, retrieves evidence, and deletes cleanly', (
    tester,
  ) async {
    final db = await AppDatabase.open();
    final service = DocumentService(db);
    final file = File(
      p.join((await getTemporaryDirectory()).path, 'academic-smoke.pdf'),
    );
    await file.writeAsBytes(
      _simplePdf('Mitosis divides one cell into two daughter cells.'),
      flush: true,
    );
    int? id;
    try {
      id = await service.importFile(file, 'academic-smoke.pdf');
      final documents = await db.list('documents', where: 'id = ?', args: [id]);
      expect(documents.single['extraction_status'], 'ready');
      final found = await service.retrieve('How does mitosis divide cells?', [
        id,
      ]);
      expect(found, isNotEmpty);
      expect('${found.first['text']}', contains('daughter cells'));
      expect(found.first['page_number'], 1);
      expect(await service.retrieve('quantum chlorophyll', [id]), isEmpty);

      final saved = File(documents.single['local_path'] as String);
      expect(await saved.exists(), isTrue);
      await service.remove(documents.single);
      id = null;
      expect(await saved.exists(), isFalse);
      expect(
        await db.list(
          'document_chunks',
          where: 'document_id = ?',
          args: [documents.single['id']],
        ),
        isEmpty,
      );
    } finally {
      if (id != null) {
        final remaining = await db.list(
          'documents',
          where: 'id = ?',
          args: [id],
        );
        if (remaining.isNotEmpty) await service.remove(remaining.single);
      }
      if (await file.exists()) await file.delete();
      await db.db.close();
    }
  });
}

List<int> _simplePdf(String text) {
  final escaped = text
      .replaceAll('\\', '\\\\')
      .replaceAll('(', '\\(')
      .replaceAll(')', '\\)');
  final stream = 'BT /F1 16 Tf 50 740 Td ($escaped) Tj ET\n';
  final objects = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
    '<< /Length ${ascii.encode(stream).length} >>\nstream\n${stream}endstream',
  ];
  final output = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[0];
  for (var i = 0; i < objects.length; i++) {
    offsets.add(ascii.encode(output.toString()).length);
    output.write('${i + 1} 0 obj\n${objects[i]}\nendobj\n');
  }
  final xref = ascii.encode(output.toString()).length;
  output.write('xref\n0 ${objects.length + 1}\n0000000000 65535 f \n');
  for (final offset in offsets.skip(1)) {
    output.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
  }
  output.write(
    'trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n',
  );
  return ascii.encode(output.toString());
}
