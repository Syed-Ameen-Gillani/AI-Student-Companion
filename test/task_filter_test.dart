import 'package:ai_legal_assistant/features/tasks/tasks_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 15, 9);
  Map<String, Object?> task(DateTime due, {String status = 'open'}) => {
    'title': 'Assignment',
    'description': '',
    'subject': 'Biology',
    'due_at': due.toUtc().toIso8601String(),
    'status': status,
    'has_time': 0,
  };

  test(
    'date-only filters use local calendar day and ignore completed overdue',
    () {
      final yesterday = task(DateTime(2026, 10, 14));
      final today = task(DateTime(2026, 10, 15));
      final tomorrow = task(DateTime(2026, 10, 16));
      expect(
        taskMatches(yesterday, query: '', filter: 'overdue', now: now),
        isTrue,
      );
      expect(taskMatches(today, query: '', filter: 'today', now: now), isTrue);
      expect(
        taskMatches(tomorrow, query: '', filter: 'upcoming', now: now),
        isTrue,
      );
      expect(
        taskMatches(
          task(DateTime(2026, 10, 14), status: 'done'),
          query: '',
          filter: 'overdue',
          now: now,
        ),
        isFalse,
      );
    },
  );

  test('invalid AI task actions cannot create a draft', () {
    expect(
      () => parseTaskDraft(
        '{"title":"Exam","description":"","subject":"Math","category":"delete","priority":"high","due_at":null,"has_time":false,"ambiguous":false}',
      ),
      throwsFormatException,
    );
    expect(
      () => parseTaskDraft(
        '{"title":"Exam","description":"","subject":"Math","category":"exam","priority":"high","due_at":"not a date","has_time":true,"ambiguous":false}',
      ),
      throwsFormatException,
    );
  });

  test('ambiguous AI date stays empty for editable confirmation', () {
    final draft = parseTaskDraft(
      '{"title":"Exam","description":"","subject":"Math","category":"exam","priority":"high","due_at":null,"has_time":false,"ambiguous":true}',
    );
    expect(draft['ambiguous'], isTrue);
    expect(draft['due_at'], isNull);
  });
}
