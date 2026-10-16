import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/database/app_database.dart';
import '../../core/database/backup_service.dart';
import '../../core/network/gemini_service.dart';
import '../../main.dart' show confirm, showError;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.store,
    required this.gemini,
    required this.theme,
    required this.onTheme,
    required this.onChange,
    this.geminiOnly = false,
  });
  final StudyRepository store;
  final AiService gemini;
  final String theme;
  final ValueChanged<String> onTheme;
  final VoidCallback onChange;
  final bool geminiOnly;
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final model = TextEditingController();
  bool hasKey = false;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    model.text =
        await widget.store.setting('model') ?? GeminiService.defaultModel;
    hasKey = await widget.gemini.hasKey;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    model.dispose();
    super.dispose();
  }

  Future<void> editKey() async {
    var enteredKey = '';
    final key = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gemini API key'),
        content: TextField(
          onChanged: (value) => enteredKey = value,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'API key'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, enteredKey.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (key == null || key.isEmpty || !mounted) return;
    await widget.gemini.saveKey(key);
    setState(() => hasKey = true);
  }

  Future<void> validateKey() async {
    setState(() => busy = true);
    try {
      await widget.gemini.generate(
        prompt: 'Reply with OK.',
        model: model.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gemini connection succeeded.')),
        );
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> exportBackup() async {
    setState(() => busy = true);
    try {
      final bytes = await BackupService(widget.store).createArchive();
      final output = File(
        p.join(
          (await getTemporaryDirectory()).path,
          'student-companion-backup.zip',
        ),
      );
      await output.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(output.path)],
          text: 'Student Companion backup (API key excluded)',
        ),
      );
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> restore() async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (picked?.path == null) return;
    setState(() => busy = true);
    try {
      final service = BackupService(widget.store);
      final backup = service.prepare(await File(picked!.path!).readAsBytes());
      if (!mounted ||
          !await confirm(
            context,
            'Replace local data?',
            'This will replace all current notes, tasks, chats, and documents. The Gemini key will stay as it is.',
          )) {
        return;
      }
      final directory = Directory(
        p.join((await getApplicationDocumentsDirectory()).path, 'imports'),
      );
      await service.restore(backup, directory);
      await widget.store.setSetting('setup_done', 'yes');
      widget.onChange();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Backup restored.')));
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
    children: [
      if (!widget.geminiOnly) ...[
        Text('Preferences', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          'Personalize your workspace and manage local data.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 28),
      ],
      if (widget.geminiOnly) ...[
        Text('Connection', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        Card(
          child: Column(
            children: [
              ListTile(
                title: Text(hasKey ? 'API key saved securely' : 'No API key'),
                subtitle: const Text(
                  'Your key is stored in device secure storage, outside the SQLite database.',
                ),
                trailing: FilledButton(
                  onPressed: editKey,
                  child: Text(hasKey ? 'Replace' : 'Add key'),
                ),
              ),
              if (hasKey)
                ListTile(
                  title: const Text('Delete API key'),
                  trailing: const Icon(Icons.delete_outline),
                  onTap: () async {
                    if (await confirm(
                      context,
                      'Delete key?',
                      'AI requests will stop until you add a key again.',
                    )) {
                      await widget.gemini.deleteKey();
                      setState(() => hasKey = false);
                    }
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: model,
          decoration: const InputDecoration(
            labelText: 'Model ID',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton(
              onPressed: () async {
                await widget.store.setSetting('model', model.text.trim());
                if (mounted) {
                  ScaffoldMessenger.of(
                    this.context,
                  ).showSnackBar(const SnackBar(content: Text('Model saved.')));
                }
              },
              child: const Text('Save model'),
            ),
            OutlinedButton(
              onPressed: busy ? null : validateKey,
              child: const Text('Test connection'),
            ),
          ],
        ),
        const SizedBox(height: 28),
      ],
      if (!widget.geminiOnly) ...[
        Text('Appearance', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: widget.theme,
          items: [
            for (final v in ['system', 'light', 'dark'])
              DropdownMenuItem(value: v, child: Text(v)),
          ],
          onChanged: (value) {
            if (value != null) widget.onTheme(value);
          },
        ),
        const SizedBox(height: 28),
        Text('Your data', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        Card(
          child: Column(
            children: [
              ListTile(
                title: const Text('Export backup'),
                subtitle: const Text(
                  'Includes local records and imported files; excludes API key.',
                ),
                trailing: const Icon(Icons.ios_share),
                onTap: busy ? null : exportBackup,
              ),
              ListTile(
                title: const Text('Restore backup'),
                trailing: const Icon(Icons.restore),
                onTap: busy ? null : restore,
              ),
              ListTile(
                title: const Text('Clear conversations'),
                trailing: const Icon(Icons.delete_outline),
                onTap: () async {
                  if (await confirm(
                    context,
                    'Clear conversations?',
                    'All saved chats will be deleted.',
                  )) {
                    await widget.store.db.delete('conversations');
                    widget.onChange();
                  }
                },
              ),
              ListTile(
                title: const Text('Reset local data'),
                trailing: const Icon(Icons.warning_amber),
                onTap: () async {
                  if (!await confirm(
                    context,
                    'Reset local data?',
                    'Delete all notes, tasks, chats, and imported documents?',
                  )) {
                    return;
                  }
                  final docs = await widget.store.list('documents');
                  await widget.store.db.transaction((txn) async {
                    for (final table in [
                      'conversations',
                      'notes',
                      'tasks',
                      'documents',
                    ]) {
                      await txn.delete(table);
                    }
                  });
                  for (final doc in docs) {
                    final file = File(doc['local_path'] as String);
                    if (await file.exists()) await file.delete();
                  }
                  widget.onChange();
                },
              ),
            ],
          ),
        ),
      ],
      if (busy) const LinearProgressIndicator(),
    ],
  );
}
