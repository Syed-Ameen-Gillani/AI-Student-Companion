import 'package:flutter/material.dart';
import '../../core/database/app_database.dart';
import '../../core/network/gemini_service.dart';
import '../../core/widgets/study_ui.dart';
import '../../main.dart' show confirm, showError;

class NotesScreen extends StatefulWidget {
  const NotesScreen({
    super.key,
    required this.store,
    required this.gemini,
    required this.revision,
    required this.onChange,
  });
  final StudyRepository store;
  final AiService gemini;
  final int revision;
  final VoidCallback onChange;
  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  String query = '';
  String sort = 'recent';
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your notes',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Ideas, summaries, and study material in one place.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search notes',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() => query = value),
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              tooltip: 'Sort',
              icon: const Icon(Icons.sort),
              initialValue: sort,
              onSelected: (value) => setState(() => sort = value),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'recent', child: Text('Recent')),
                PopupMenuItem(value: 'title', child: Text('Title')),
                PopupMenuItem(value: 'pinned', child: Text('Pinned')),
              ],
            ),
          ],
        ),
      ),
      Expanded(
        child: FutureBuilder(
          future: widget.store.list(
            'notes',
            orderBy: sort == 'title'
                ? 'title COLLATE NOCASE'
                : sort == 'pinned'
                ? 'pinned DESC, updated_at DESC'
                : 'updated_at DESC',
          ),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final notes = snapshot.data!
                .where(
                  (n) =>
                      '${n['title']} ${n['body']} ${n['subject']} ${n['tags']}'
                          .toLowerCase()
                          .contains(query.toLowerCase()),
                )
                .toList();
            if (notes.isEmpty) {
              return EmptyState(
                icon: Icons.note_alt_outlined,
                title: query.isEmpty
                    ? 'A clear page to begin'
                    : 'No matching notes',
                detail: query.isEmpty
                    ? 'Create a note for a class, reading, or idea.'
                    : 'Try a different search term.',
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 8),
              itemCount: notes.length,
              itemBuilder: (context, index) {
                final note = notes[index];
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
                    leading: SoftIcon(
                      note['pinned'] == 1
                          ? Icons.push_pin_outlined
                          : Icons.description_outlined,
                    ),
                    title: Text(
                      '${note['title']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${note['subject']}'.isEmpty
                          ? '${note['body']}'
                          : '${note['subject']} · ${note['body']}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => edit(note),
                    trailing: PopupMenuButton<String>(
                      onSelected: (action) async {
                        if (action == 'pin') {
                          await widget.store
                              .update('notes', note['id'] as int, {
                                'pinned': note['pinned'] == 1 ? 0 : 1,
                                'updated_at': widget.store.now,
                              });
                          widget.onChange();
                        }
                        if (action == 'delete' &&
                            context.mounted &&
                            await confirm(
                              context,
                              'Delete note?',
                              '${note['title']} will be removed.',
                            )) {
                          await widget.store.delete('notes', note['id'] as int);
                          widget.onChange();
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'pin',
                          child: Text(note['pinned'] == 1 ? 'Unpin' : 'Pin'),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete'),
                        ),
                      ],
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
            onPressed: () => edit(null),
            icon: const Icon(Icons.add),
            label: const Text('New note'),
          ),
        ),
      ),
    ],
  );
  Future<void> edit(Map<String, Object?>? note) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            NoteEditor(store: widget.store, gemini: widget.gemini, note: note),
      ),
    );
    widget.onChange();
  }
}

class NoteEditor extends StatefulWidget {
  const NoteEditor({
    super.key,
    required this.store,
    required this.gemini,
    this.note,
  });
  final StudyRepository store;
  final AiService gemini;
  final Map<String, Object?>? note;
  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  late final title = TextEditingController(
    text: '${widget.note?['title'] ?? ''}',
  );
  late final body = TextEditingController(
    text: '${widget.note?['body'] ?? ''}',
  );
  late final subject = TextEditingController(
    text: '${widget.note?['subject'] ?? ''}',
  );
  late final tags = TextEditingController(
    text: '${widget.note?['tags'] ?? ''}',
  );
  bool pinned = false;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    pinned = widget.note?['pinned'] == 1;
  }

  @override
  void dispose() {
    title.dispose();
    body.dispose();
    subject.dispose();
    tags.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (title.text.trim().isEmpty) {
      showError(context, 'Add a title.');
      return;
    }
    final values = {
      'title': title.text.trim(),
      'body': body.text,
      'subject': subject.text.trim(),
      'tags': tags.text.trim(),
      'pinned': pinned ? 1 : 0,
      'updated_at': widget.store.now,
    };
    if (widget.note?['id'] == null) {
      await widget.store.insert('notes', {
        ...values,
        'created_at': widget.store.now,
      });
    } else {
      await widget.store.update('notes', widget.note!['id'] as int, values);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> ai(String action) async {
    if (body.text.trim().isEmpty) {
      showError(context, 'Add note text first.');
      return;
    }
    if (!await confirm(
      context,
      'Send note to Gemini?',
      'The current note body will be sent to Google for $action.',
    )) {
      return;
    }
    setState(() => busy = true);
    try {
      final model =
          await widget.store.setting('model') ?? GeminiService.defaultModel;
      final result = await widget.gemini.generate(
        model: model,
        prompt:
            '$action the following study note. Return only the result.\n\n${body.text}',
      );
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(action),
          content: SizedBox(
            width: 550,
            child: SingleChildScrollView(child: SelectableText(result)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Discard'),
            ),
            TextButton(
              onPressed: () {
                body.text += '\n\n$result';
                Navigator.pop(context);
              },
              child: const Text('Append'),
            ),
            TextButton(
              onPressed: () {
                body.text = result;
                Navigator.pop(context);
              },
              child: const Text('Replace'),
            ),
            FilledButton(
              onPressed: () async {
                await widget.store.insert('notes', {
                  'title': '${title.text} ($action)',
                  'body': result,
                  'subject': subject.text,
                  'tags': tags.text,
                  'pinned': 0,
                  'created_at': widget.store.now,
                  'updated_at': widget.store.now,
                });
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save new'),
            ),
          ],
        ),
      );
      setState(() {});
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.note == null ? 'New note' : 'Edit note'),
      actions: [TextButton(onPressed: save, child: const Text('Save'))],
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: title,
          decoration: const InputDecoration(
            labelText: 'Title',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: subject,
          decoration: const InputDecoration(
            labelText: 'Subject',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: tags,
          decoration: const InputDecoration(
            labelText: 'Tags (comma separated)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: body,
          maxLines: 12,
          decoration: const InputDecoration(
            labelText: 'Note',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
        SwitchListTile(
          title: const Text('Pin note'),
          value: pinned,
          onChanged: (value) => setState(() => pinned = value),
        ),
        if (busy) const LinearProgressIndicator(),
        Wrap(
          spacing: 8,
          children: [
            for (final action in [
              'Summarize',
              'Organize into bullet points',
              'Explain simply',
              'Extract key concepts',
              'Suggest a title',
            ])
              ActionChip(
                label: Text(action),
                onPressed: busy ? null : () => ai(action),
              ),
          ],
        ),
      ],
    ),
  );
}
