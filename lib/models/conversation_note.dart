class ConversationNote {
  const ConversationNote({
    required this.conversationId,
    required this.content,
    required this.updatedAt,
  });

  final String conversationId;
  final String content;
  final DateTime updatedAt;

  Map<String, Object?> toMap() {
    return {
      'conversation_id': conversationId,
      'content': content,
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  factory ConversationNote.fromMap(Map<String, Object?> map) {
    return ConversationNote(
      conversationId: map['conversation_id'] as String,
      content: map['content'] as String,
      updatedAt: DateTime.parse(map['updated_at'] as String).toUtc(),
    );
  }

  ConversationNote copyWith({String? content, DateTime? updatedAt}) {
    return ConversationNote(
      conversationId: conversationId,
      content: content ?? this.content,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
