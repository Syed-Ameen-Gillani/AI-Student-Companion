import 'package:flutter/material.dart';
import '../../core/database/app_database.dart';
import '../../core/widgets/study_ui.dart';
import '../../main.dart' show confirm, showError;
import 'document_service.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    required this.store,
    required this.revision,
    required this.onChange,
  });
  final StudyRepository store;
  final int revision;
  final VoidCallback onChange;
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  bool busy = false;
  Future<void> import() async {
    setState(() => busy = true);
    try {
      await DocumentService(widget.store).pickAndImport();
      widget.onChange();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> details(Map<String, Object?> document) async {
    final chunks = await widget.store.list(
      'document_chunks',
      where: 'document_id = ?',
      args: [document['id']],
      orderBy: 'position',
    );
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text('${document['name']}')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '${document['format']?.toString().toUpperCase()} · ${chunks.length} searchable excerpts',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              for (final chunk in chunks)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Excerpt ${(chunk['position'] as int) + 1}',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        if (chunk['page_number'] != null)
                          Text('Page ${chunk['page_number']}'),
                        const SizedBox(height: 6),
                        SelectableText('${chunk['text']}'),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (busy) const LinearProgressIndicator(),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your library',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Bring your reading into the conversation.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      'Text PDFs and TXT files are searchable offline. Scanned PDFs need OCR and are not supported.',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      Expanded(
        child: FutureBuilder(
          future: widget.store.list('documents', orderBy: 'created_at DESC'),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final documents = snapshot.data!;
            if (documents.isEmpty) {
              return const EmptyState(
                icon: Icons.folder_open_outlined,
                title: 'No material yet',
                detail:
                    'Import a PDF or TXT file to ask questions grounded in your own reading.',
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 8),
              itemCount: documents.length,
              itemBuilder: (context, index) {
                final doc = documents[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 5,
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 7,
                    ),
                    leading: const SoftIcon(Icons.description_outlined),
                    title: Text(
                      '${doc['name']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${doc['format']} · ${doc['extraction_status']}',
                    ),
                    onTap: () => details(doc),
                    trailing: IconButton(
                      tooltip: 'Delete document',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        if (await confirm(
                          context,
                          'Delete document?',
                          'The local file and searchable excerpts will be removed.',
                        )) {
                          await DocumentService(widget.store).remove(doc);
                          widget.onChange();
                        }
                      },
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: busy ? null : import,
            icon: const Icon(Icons.upload_file),
            label: const Text('Import document'),
          ),
        ),
      ),
    ],
  );
}
