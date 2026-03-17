class TodoItem {
  const TodoItem({
    required this.id,
    required this.conversationId,
    required this.text,
    required this.isDone,
    required this.sortOrder,
    required this.createdAt,
  });

  final String id;
  final String conversationId;
  final String text;
  final bool isDone;
  final int sortOrder;
  final DateTime createdAt;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'text': text,
      'is_done': isDone ? 1 : 0,
      'sort_order': sortOrder,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  factory TodoItem.fromMap(Map<String, Object?> map) {
    return TodoItem(
      id: map['id'] as String,
      conversationId: map['conversation_id'] as String,
      text: map['text'] as String,
      isDone: (map['is_done'] as int) == 1,
      sortOrder: map['sort_order'] as int,
      createdAt: DateTime.parse(map['created_at'] as String).toUtc(),
    );
  }

  TodoItem copyWith({String? text, bool? isDone, int? sortOrder}) {
    return TodoItem(
      id: id,
      conversationId: conversationId,
      text: text ?? this.text,
      isDone: isDone ?? this.isDone,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
    );
  }
}
