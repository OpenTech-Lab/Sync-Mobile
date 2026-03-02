class LocalChatMessage {
  const LocalChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String body;
  final DateTime createdAt;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'body': body,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  factory LocalChatMessage.fromMap(Map<String, Object?> map) {
    return LocalChatMessage(
      id: map['id'] as String,
      conversationId: map['conversation_id'] as String,
      senderId: map['sender_id'] as String,
      body: map['body'] as String,
      createdAt: DateTime.parse(map['created_at'] as String).toUtc(),
    );
  }
}
