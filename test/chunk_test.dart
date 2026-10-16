import 'package:flutter_test/flutter_test.dart';
import 'package:ai_legal_assistant/features/library/document_service.dart';

void main() {
  test('chunking preserves text with overlap', () {
    final chunks = DocumentService.chunkText(
      'one two three four five six seven',
      size: 16,
      overlap: 4,
    );
    expect(chunks.length, greaterThan(1));
    expect(chunks.first, startsWith('one two'));
    expect(chunks.last, endsWith('seven'));
  });
}
