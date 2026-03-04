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
    return ServerNewsItem(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      summary: (json['summary'] as String?)?.trim(),
      markdownContent: json['markdown_content'] as String? ?? '',
      publishedAt:
          DateTime.tryParse(json['published_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
    );
  }
}
