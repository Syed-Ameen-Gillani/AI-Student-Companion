import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/database/app_database.dart';
import '../../core/network/gemini_service.dart';
import '../../core/widgets/study_ui.dart';
import '../../main.dart' show confirm, showError;

class TasksScreen extends StatefulWidget {
  const TasksScreen({
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
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  String filter = 'all';
  String query = '';
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
                'Plan your work',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Assignments, exams, and study sessions.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        child: TextField(
          decoration: const InputDecoration(
            hintText: 'Search tasks',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => setState(() => query = value),
        ),
      ),
      SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 17),
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final value in [
              'all',
              'today',
              'upcoming',
              'overdue',
              'completed',
            ])
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: ChoiceChip(
                  label: Text(value[0].toUpperCase() + value.substring(1)),
                  selected: filter == value,
                  onSelected: (_) => setState(() => filter = value),
                ),
              ),
          ],
        ),
      ),
      Expanded(
        child: FutureBuilder(
          future: widget.store.list(
            'tasks',
            orderBy: 'due_at ASC, updated_at DESC',
          ),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final tasks = snapshot.data!
                .where((task) => matches(task))
                .toList();
            if (tasks.isEmpty) {
              return EmptyState(
                icon: Icons.task_alt_outlined,
                title: filter == 'all'
                    ? 'Nothing on your list yet'
                    : 'No tasks here',
                detail: filter == 'all'
                    ? 'Add an assignment, exam, or study session to get started.'
                    : 'Try another filter or add a new task.',
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.only(top: 10, bottom: 8),
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final task = tasks[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 5,
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    leading: Checkbox(
                      value: task['status'] == 'done',
                      onChanged: (done) async {
                        await widget.store.update('tasks', task['id'] as int, {
                          'status': done == true ? 'done' : 'open',
                          'updated_at': widget.store.now,
                        });
                        widget.onChange();
                      },
                    ),
                    title: Text(
                      '${task['title']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: task['status'] == 'done'
                          ? const TextStyle(
                              decoration: TextDecoration.lineThrough,
                            )
                          : const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${task['subject']}'.isEmpty
                          ? '${task['category']} · ${formatDue(task)}'
                          : '${task['subject']} · ${formatDue(task)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => edit(task),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Delete',
                      onPressed: () async {
                        if (await confirm(
                          context,
                          'Delete task?',
                          '${task['title']} will be removed.',
                        )) {
                          await widget.store.delete('tasks', task['id'] as int);
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
        child: Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => edit(null),
                icon: const Icon(Icons.add),
                label: const Text('New task'),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: aiDraft,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Describe'),
            ),
          ],
        ),
      ),
    ],
  );
  bool matches(Map<String, Object?> task) =>
      taskMatches(task, query: query, filter: filter, now: DateTime.now());

  Future<void> edit(Map<String, Object?>? task) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaskEditor(store: widget.store, task: task),
      ),
    );
    widget.onChange();
  }

  Future<void> aiDraft() async {
    var enteredRequest = '';
    final request = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Describe a task'),
        content: TextField(
          onChanged: (value) => enteredRequest = value,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Add my biology assignment next Friday at 5 PM',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, enteredRequest),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (request == null || request.trim().isEmpty || !mounted) return;
    try {
      final answer = await widget.gemini.generate(
        model:
            await widget.store.setting('model') ?? GeminiService.defaultModel,
        prompt:
            'Today is ${DateTime.now().toIso8601String()}; timezone offset is ${DateTime.now().timeZoneOffset}. Parse this student task: $request. Return only JSON with title, description, category (assignment/exam/study/general), subject, due_at (ISO 8601 local datetime or null), has_time (boolean), priority (low/normal/high), ambiguous (boolean). Never invent a deadline. If ambiguous, set ambiguous true and due_at null.',
      );
      final raw = parseTaskDraft(answer);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TaskEditor(store: widget.store, draft: raw),
        ),
      );
      widget.onChange();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }
}

bool taskMatches(
  Map<String, Object?> task, {
  required String query,
  required String filter,
  required DateTime now,
}) {
  if (!'${task['title']} ${task['description']} ${task['subject']}'
      .toLowerCase()
      .contains(query.toLowerCase())) {
    return false;
  }
  if (filter == 'all') return true;
  if (filter == 'completed') return task['status'] == 'done';
  if (task['status'] == 'done') return false;
  final due = DateTime.tryParse('${task['due_at']}')?.toLocal();
  if (due == null) return false;
  final today = DateUtils.dateOnly(now);
  final date = DateUtils.dateOnly(due);
  if (filter == 'today') return date == today;
  if (filter == 'overdue') return date.isBefore(today);
  return date.isAfter(today);
}

Map<String, dynamic> parseTaskDraft(String response) {
  final value = jsonDecode(
    response.replaceAll('```json', '').replaceAll('```', '').trim(),
  );
  if (value is! Map<String, dynamic> ||
      value['title'] is! String ||
      (value['title'] as String).trim().isEmpty ||
      value['description'] is! String ||
      value['subject'] is! String ||
      !['assignment', 'exam', 'study', 'general'].contains(value['category']) ||
      !['low', 'normal', 'high'].contains(value['priority']) ||
      value['has_time'] is! bool ||
      value['ambiguous'] is! bool ||
      (value['due_at'] != null &&
          (value['due_at'] is! String ||
              DateTime.tryParse(value['due_at'] as String) == null)) ||
      (value['due_at'] == null && value['has_time'] == true) ||
      (value['ambiguous'] == true && value['due_at'] != null)) {
    throw const FormatException(
      'Gemini returned an invalid task draft. Please enter the task manually.',
    );
  }
  return value;
}

String formatDue(Map<String, Object?> task) {
  final raw = task['due_at'];
  if (raw == null) return 'No due date';
  final date = DateTime.tryParse('$raw')?.toLocal();
  if (date == null) return 'No due date';
  return DateFormat(
    task['has_time'] == 1 ? 'MMM d, yyyy · h:mm a' : 'MMM d, yyyy',
  ).format(date);
}

class TaskEditor extends StatefulWidget {
  const TaskEditor({super.key, required this.store, this.task, this.draft});
  final StudyRepository store;
  final Map<String, Object?>? task;
  final Map<String, Object?>? draft;
  @override
  State<TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<TaskEditor> {
  late final title = TextEditingController(
    text: '${widget.task?['title'] ?? widget.draft?['title'] ?? ''}',
  );
  late final description = TextEditingController(
    text:
        '${widget.task?['description'] ?? widget.draft?['description'] ?? ''}',
  );
  late final subject = TextEditingController(
    text: '${widget.task?['subject'] ?? widget.draft?['subject'] ?? ''}',
  );
  late String category =
      '${widget.task?['category'] ?? widget.draft?['category'] ?? 'general'}';
  late String priority =
      '${widget.task?['priority'] ?? widget.draft?['priority'] ?? 'normal'}';
  DateTime? due;
  bool hasTime = false;
  @override
  void initState() {
    super.initState();
    due = DateTime.tryParse(
      '${widget.task?['due_at'] ?? widget.draft?['due_at']}',
    )?.toLocal();
    hasTime =
        widget.task?['has_time'] == 1 || widget.draft?['has_time'] == true;
    if (!['assignment', 'exam', 'study', 'general'].contains(category)) {
      category = 'general';
    }
    if (!['low', 'normal', 'high'].contains(priority)) priority = 'normal';
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    subject.dispose();
    super.dispose();
  }

  Future<void> pickDate() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: due ?? DateTime.now(),
    );
    if (date != null) setState(() => due = date);
  }

  Future<void> pickTime() async {
    if (due == null) await pickDate();
    if (due == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(due!),
    );
    if (time != null) {
      setState(() {
        due = DateTime(due!.year, due!.month, due!.day, time.hour, time.minute);
        hasTime = true;
      });
    }
  }

  Future<void> save() async {
    if (title.text.trim().isEmpty) {
      showError(context, 'Add a title.');
      return;
    }
    if (widget.draft?['ambiguous'] == true && due == null) {
      final saveWithoutDeadline = await confirm(
        context,
        'Save without a deadline?',
        'The date in your request was unclear. Choose a deadline, or confirm that this task has none.',
      );
      if (!saveWithoutDeadline || !mounted) return;
    }
    final values = <String, Object?>{
      'title': title.text.trim(),
      'description': description.text,
      'subject': subject.text.trim(),
      'category': category,
      'priority': priority,
      'due_at': due?.toUtc().toIso8601String(),
      'has_time': hasTime ? 1 : 0,
      'status': widget.task?['status'] ?? 'open',
      'updated_at': widget.store.now,
    };
    if (widget.task == null) {
      await widget.store.insert('tasks', {
        ...values,
        'created_at': widget.store.now,
      });
    } else {
      await widget.store.update('tasks', widget.task!['id'] as int, values);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.task == null ? 'New task' : 'Edit task'),
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
          controller: description,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Description',
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
        DropdownButtonFormField<String>(
          initialValue: category,
          decoration: const InputDecoration(
            labelText: 'Category',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final v in ['assignment', 'exam', 'study', 'general'])
              DropdownMenuItem(value: v, child: Text(v)),
          ],
          onChanged: (value) => setState(() => category = value!),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: priority,
          decoration: const InputDecoration(
            labelText: 'Priority',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final v in ['low', 'normal', 'high'])
              DropdownMenuItem(value: v, child: Text(v)),
          ],
          onChanged: (value) => setState(() => priority = value!),
        ),
        ListTile(
          title: Text(
            due == null
                ? 'No deadline'
                : DateFormat('MMM d, yyyy').format(due!),
          ),
          trailing: const Icon(Icons.calendar_today),
          onTap: pickDate,
        ),
        ListTile(
          title: Text(
            hasTime && due != null
                ? DateFormat('h:mm a').format(due!)
                : 'No time set',
          ),
          trailing: const Icon(Icons.access_time),
          onTap: pickTime,
        ),
        if (due != null)
          TextButton(
            onPressed: () => setState(() {
              due = null;
              hasTime = false;
            }),
            child: const Text('Clear deadline'),
          ),
      ],
    ),
  );
}
