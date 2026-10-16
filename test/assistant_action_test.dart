import 'package:ai_legal_assistant/core/network/assistant_action.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('valid note and task actions produce reviewable drafts', () {
    final note = AssistantAction.parse(
      '{"action":"draft_note","title":"Mitosis","body":"Cells divide.","subject":"Biology","tags":"cells"}',
      mode: 'Notes',
    );
    expect(note.type, 'draft_note');
    expect(note.data['body'], 'Cells divide.');
    expect(AssistantAction.fromStored(note.storedJson)?.data, note.data);

    final task = AssistantAction.parse(
      '{"action":"draft_task","title":"Lab report","description":"Finish draft","subject":"Biology","category":"assignment","priority":"normal","due_at":null,"has_time":false,"ambiguous":true}',
      mode: 'Tasks',
    );
    expect(task.data['due_at'], isNull);
    expect(task.displayMessage, contains('unclear'));
  });

  test('unknown and cross-mode actions are rejected', () {
    expect(
      () => AssistantAction.parse(
        '{"action":"delete_note","id":1}',
        mode: 'Notes',
      ),
      throwsFormatException,
    );
    expect(
      () => AssistantAction.parse(
        '{"action":"draft_note","title":"X","body":"Y"}',
        mode: 'Tasks',
      ),
      throwsFormatException,
    );
    expect(
      () => AssistantAction.parse(
        '{"action":"draft_task","title":"Exam","description":"","subject":"","category":"exam","priority":"high","due_at":"tomorrow","has_time":true,"ambiguous":false}',
        mode: 'Tasks',
      ),
      throwsFormatException,
    );
    expect(AssistantAction.fromStored('{"action":"delete_note"}'), isNull);
  });
}
