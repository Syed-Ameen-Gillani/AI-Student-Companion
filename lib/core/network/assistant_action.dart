import 'dart:convert';

/// A deliberately small set of actions the assistant may propose.
/// Parsing never writes data; editors require an explicit user Save.
class AssistantAction {
  AssistantAction._(this.type, this.data);

  final String type;
  final Map<String, Object?> data;

  static AssistantAction parse(String response, {required String mode}) {
    final decoded = jsonDecode(response.trim());
    if (decoded is! Map<String, dynamic> || decoded['action'] is! String) {
      throw const FormatException(
        'Gemini returned an invalid action. Please try again.',
      );
    }
    final type = decoded['action'] as String;
    if (type == 'reply') {
      return AssistantAction._(type, {
        'message': _text(decoded, 'message', 20000),
      });
    }
    if (mode == 'Notes' && type == 'draft_note') {
      return AssistantAction._(type, {
        'title': _text(decoded, 'title', 200),
        'body': _text(decoded, 'body', 20000),
        'subject': _text(decoded, 'subject', 200, required: false),
        'tags': _text(decoded, 'tags', 500, required: false),
      });
    }
    if (mode == 'Tasks' && type == 'show_upcoming_tasks') {
      return AssistantAction._(type, {});
    }
    if (mode == 'Tasks' && type == 'draft_task') {
      final category = _text(decoded, 'category', 20);
      final priority = _text(decoded, 'priority', 20);
      final dueAt = decoded['due_at'];
      final hasTime = decoded['has_time'];
      final ambiguous = decoded['ambiguous'];
      if (!{'assignment', 'exam', 'study', 'general'}.contains(category) ||
          !{'low', 'normal', 'high'}.contains(priority) ||
          hasTime is! bool ||
          ambiguous is! bool ||
          (dueAt != null &&
              (dueAt is! String || DateTime.tryParse(dueAt) == null)) ||
          (dueAt == null && hasTime) ||
          (ambiguous && dueAt != null)) {
        throw const FormatException(
          'Gemini returned an invalid task draft. Please try again.',
        );
      }
      return AssistantAction._(type, {
        'title': _text(decoded, 'title', 200),
        'description': _text(decoded, 'description', 20000, required: false),
        'subject': _text(decoded, 'subject', 200, required: false),
        'category': category,
        'priority': priority,
        'due_at': dueAt,
        'has_time': hasTime,
        'ambiguous': ambiguous,
      });
    }
    throw const FormatException(
      'Gemini returned an unsupported action. No note or task was changed.',
    );
  }

  static AssistantAction? fromStored(Object? value) {
    if (value is! String || value.isEmpty) return null;
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, dynamic>) return null;
      final type = decoded['action'];
      if (type != 'draft_note' && type != 'draft_task') return null;
      return parse(value, mode: type == 'draft_note' ? 'Notes' : 'Tasks');
    } catch (_) {
      return null;
    }
  }

  String get displayMessage => switch (type) {
    'draft_note' => 'Note draft ready. Review it before saving.',
    'draft_task' =>
      data['ambiguous'] == true
          ? 'Task draft ready. The deadline is unclear; choose it before saving.'
          : 'Task draft ready. Review it before saving.',
    _ => data['message'] as String? ?? '',
  };

  String? get storedJson => type == 'draft_note' || type == 'draft_task'
      ? jsonEncode({'action': type, ...data})
      : null;

  static String _text(
    Map<String, dynamic> data,
    String key,
    int max, {
    bool required = true,
  }) {
    final value = data[key];
    if (value == null && !required) return '';
    if (value is! String ||
        value.length > max ||
        (required && value.trim().isEmpty)) {
      throw FormatException(
        'Gemini returned an invalid $key. Please try again.',
      );
    }
    return value.trim();
  }
}
