class ServerNewsItem {
  const ServerNewsItem({
    required this.id,
    required this.title,
    required this.summary,
    required this.markdownContent,
    required this.publishedAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String? summary;
  final String markdownContent;
  final DateTime publishedAt;
  final DateTime? updatedAt;

  factory ServerNewsItem.fromJson(Map<String, dynamic> json) {
    return ServerNewsItem.fromMap(json);
  }

  factory ServerNewsItem.fromMap(Map<String, dynamic> map) {
    return ServerNewsItem(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      summary: (map['summary'] as String?)?.trim(),
      markdownContent: map['markdown_content'] as String? ?? '',
      publishedAt:
          DateTime.tryParse(map['published_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.tryParse(map['updated_at'] as String? ?? ''),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'title': title,
      'summary': summary,
      'markdown_content': markdownContent,
      'published_at': publishedAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
