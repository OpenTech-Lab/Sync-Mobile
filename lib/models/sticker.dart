class Sticker {
  const Sticker({
    required this.id,
    required this.groupName,
    required this.name,
    required this.mimeType,
    required this.contentBase64,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String groupName;
  final String name;
  final String mimeType;
  final String contentBase64;
  final String status;
  final DateTime createdAt;

  factory Sticker.fromDetailJson(Map<String, dynamic> json) {
    return Sticker(
      id: json['id'] as String,
      groupName: (json['group_name'] as String?) ?? 'General',
      name: json['name'] as String,
      mimeType: json['mime_type'] as String,
      contentBase64: (json['content_base64'] as String?) ?? '',
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
    );
  }

  factory Sticker.fromMap(Map<String, dynamic> map) {
    return Sticker(
      id: map['id'] as String,
      groupName: (map['group_name'] as String?) ?? 'General',
      name: map['name'] as String,
      mimeType: map['mime_type'] as String,
      contentBase64: map['content_base64'] as String,
      status: map['status'] as String,
      createdAt: DateTime.parse(map['created_at'] as String).toUtc(),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'group_name': groupName,
      'name': name,
      'mime_type': mimeType,
      'content_base64': contentBase64,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
