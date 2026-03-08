class ChatRoom {
  const ChatRoom({
    required this.id,
    required this.name,
    required this.memberCount,
    required this.unreadCount,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessagePreview,
    this.lastMessageAt,
  });

  final String id;
  final String name;
  final int memberCount;
  final int unreadCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? lastMessagePreview;
  final DateTime? lastMessageAt;

  String get conversationId => roomConversationId(id);

  ChatRoom copyWith({
    String? name,
    int? memberCount,
    int? unreadCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? lastMessagePreview,
    bool clearLastMessagePreview = false,
    DateTime? lastMessageAt,
    bool clearLastMessageAt = false,
  }) {
    return ChatRoom(
      id: id,
      name: name ?? this.name,
      memberCount: memberCount ?? this.memberCount,
      unreadCount: unreadCount ?? this.unreadCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastMessagePreview: clearLastMessagePreview
          ? null
          : (lastMessagePreview ?? this.lastMessagePreview),
      lastMessageAt: clearLastMessageAt
          ? null
          : (lastMessageAt ?? this.lastMessageAt),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'member_count': memberCount,
      'unread_count': unreadCount,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'last_message_preview': lastMessagePreview,
      'last_message_at': lastMessageAt?.toUtc().toIso8601String(),
    };
  }

  factory ChatRoom.fromMap(Map<String, Object?> map) {
    return ChatRoom(
      id: map['id'] as String,
      name: map['name'] as String,
      memberCount: _parseInt(map['member_count']),
      unreadCount: _parseInt(map['unread_count']),
      createdAt: DateTime.parse(map['created_at'] as String).toUtc(),
      updatedAt: DateTime.parse(map['updated_at'] as String).toUtc(),
      lastMessagePreview: map['last_message_preview'] as String?,
      lastMessageAt: map['last_message_at'] == null
          ? null
          : DateTime.parse(map['last_message_at'] as String).toUtc(),
    );
  }

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    return ChatRoom(
      id: json['id'] as String,
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? (json['name'] as String).trim()
          : 'Room',
      memberCount: _parseInt(json['member_count']),
      unreadCount: _parseInt(json['unread_count']),
      createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toUtc(),
      lastMessagePreview: (json['last_message_preview'] as String?)?.trim(),
      lastMessageAt: (json['last_message_at'] as String?) == null
          ? null
          : DateTime.parse(json['last_message_at'] as String).toUtc(),
    );
  }

  static int _parseInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return 0;
  }
}

const String roomConversationPrefix = 'room:';

String roomConversationId(String roomId) => '$roomConversationPrefix$roomId';

bool isRoomConversationId(String conversationId) {
  return conversationId.startsWith(roomConversationPrefix);
}

String? tryParseRoomId(String conversationId) {
  if (!isRoomConversationId(conversationId)) {
    return null;
  }
  final roomId = conversationId.substring(roomConversationPrefix.length).trim();
  return roomId.isEmpty ? null : roomId;
}
