import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/database/app_database.dart';
import '../../core/widgets/study_ui.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.store,
    required this.revision,
    required this.onGo,
  });
  final StudyRepository store;
  final int revision;
  final ValueChanged<int> onGo;

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: Future.wait([
      store.list('tasks', orderBy: 'due_at ASC'),
      store.list('notes', orderBy: 'updated_at DESC'),
    ]),
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final tasks = snapshot.data![0];
      final notes = snapshot.data![1];
      final now = DateTime.now();
      final today = DateUtils.dateOnly(now);
      bool active(Map<String, Object?> task) => task['status'] != 'done';
      DateTime? due(Map<String, Object?> task) =>
          DateTime.tryParse('${task['due_at']}')?.toLocal();
      final todayTasks = tasks
          .where(
            (task) =>
                active(task) &&
                due(task) != null &&
                DateUtils.isSameDay(due(task), today),
          )
          .toList();
      final overdue = tasks
          .where(
            (task) =>
                active(task) &&
                due(task) != null &&
                DateUtils.dateOnly(due(task)!).isBefore(today),
          )
          .toList();
      final upcoming = tasks
          .where(
            (task) =>
                active(task) &&
                due(task) != null &&
                DateUtils.dateOnly(due(task)!).isAfter(today),
          )
          .toList();
      return LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 700;
          final scheme = Theme.of(context).colorScheme;
          return ListView(
            padding: EdgeInsets.fromLTRB(
              wide ? 28 : 20,
              16,
              wide ? 28 : 20,
              32,
            ),
            children: [
              Text(
                DateFormat('EEEE, d MMMM').format(now).toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Your study space',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TODAY AT A GLANCE',
                            style: TextStyle(
                              color: scheme.onPrimary.withValues(alpha: .8),
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                              letterSpacing: 1.3,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            todayTasks.isEmpty
                                ? 'You have a clear day.'
                                : '${todayTasks.length} ${todayTasks.length == 1 ? 'task' : 'tasks'} due today',
                            style: TextStyle(
                              color: scheme.onPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 23,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            overdue.isEmpty
                                ? 'Keep your notes and deadlines in one place.'
                                : '${overdue.length} overdue ${overdue.length == 1 ? 'task needs' : 'tasks need'} attention.',
                            style: TextStyle(
                              color: scheme.onPrimary.withValues(alpha: .86),
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.tonalIcon(
                            onPressed: () => onGo(3),
                            icon: const Icon(Icons.arrow_forward, size: 18),
                            label: const Text('View tasks'),
                          ),
                        ],
                      ),
                    ),
                    if (wide)
                      Padding(
                        padding: const EdgeInsets.only(left: 20),
                        child: Icon(
                          Icons.auto_stories_outlined,
                          size: 90,
                          color: scheme.onPrimary.withValues(alpha: .24),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _Metric(
                    label: 'Due today',
                    value: todayTasks.length,
                    icon: Icons.today_outlined,
                    width: (constraints.maxWidth - (wide ? 76 : 60)) / 3,
                  ),
                  _Metric(
                    label: 'Overdue',
                    value: overdue.length,
                    icon: Icons.priority_high_rounded,
                    width: (constraints.maxWidth - (wide ? 76 : 60)) / 3,
                  ),
                  _Metric(
                    label: 'Upcoming',
                    value: upcoming.length,
                    icon: Icons.event_outlined,
                    width: (constraints.maxWidth - (wide ? 76 : 60)) / 3,
                  ),
                ],
              ),
              const SizedBox(height: 28),
              const SectionTitle(title: 'Jump back in'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _QuickAction(
                    label: 'Ask the assistant',
                    icon: Icons.auto_awesome_outlined,
                    onTap: () => onGo(1),
                  ),
                  _QuickAction(
                    label: 'Open notes',
                    icon: Icons.edit_note_outlined,
                    onTap: () => onGo(2),
                  ),
                  _QuickAction(
                    label: 'Import material',
                    icon: Icons.upload_file_outlined,
                    onTap: () => onGo(4),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              SectionTitle(
                title: 'Due today',
                action: 'All tasks',
                onAction: () => onGo(3),
              ),
              const SizedBox(height: 10),
              _TaskGroup(
                items: todayTasks,
                empty: 'Nothing due today',
                onTap: () => onGo(3),
              ),
              if (overdue.isNotEmpty) ...[
                const SizedBox(height: 24),
                SectionTitle(
                  title: 'Needs attention',
                  action: 'All tasks',
                  onAction: () => onGo(3),
                ),
                const SizedBox(height: 10),
                _TaskGroup(
                  items: overdue.take(4).toList(),
                  empty: '',
                  onTap: () => onGo(3),
                ),
              ],
              const SizedBox(height: 24),
              SectionTitle(
                title: 'Recent notes',
                action: 'All notes',
                onAction: () => onGo(2),
              ),
              const SizedBox(height: 10),
              if (notes.isEmpty)
                const _BlankCard(
                  text: 'Your notes will appear here after you create one.',
                ),
              for (final note in notes.take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 5,
                      ),
                      leading: const SoftIcon(Icons.description_outlined),
                      title: Text(
                        '${note['title']}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${note['subject']}'.isEmpty
                            ? 'Study note'
                            : '${note['subject']}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => onGo(2),
                    ),
                  ),
                ),
            ],
          );
        },
      );
    },
  );
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
    required this.width,
  });
  final String label;
  final int value;
  final IconData icon;
  final double width;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon, color: scheme.primary, size: 22),
                const SizedBox(height: 10),
                Text(
                  '$value',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ActionChip(
    avatar: Icon(icon, size: 19),
    label: Text(label),
    onPressed: onTap,
  );
}

class _TaskGroup extends StatelessWidget {
  const _TaskGroup({
    required this.items,
    required this.empty,
    required this.onTap,
  });
  final List<Map<String, Object?>> items;
  final String empty;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return _BlankCard(text: empty);
    return Column(
      children: [
        for (final task in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 5,
                ),
                leading: const SoftIcon(Icons.checklist_outlined),
                title: Text(
                  '${task['title']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${task['subject']}'.isEmpty
                      ? '${task['category']}'
                      : '${task['subject']} · ${task['category']}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: onTap,
              ),
            ),
          ),
      ],
    );
  }
}

class _BlankCard extends StatelessWidget {
  const _BlankCard({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
