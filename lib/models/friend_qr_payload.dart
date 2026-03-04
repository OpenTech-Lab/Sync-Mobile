import 'dart:convert';

class FriendQrPayload {
  const FriendQrPayload({required this.userId, required this.serverUrl});

  final String userId;
  final String serverUrl;

  String encode() {
    return jsonEncode({
      'type': 'sync_friend',
      'user_id': userId.trim(),
      'server_url': serverUrl.trim(),
    });
  }

  static FriendQrPayload? tryParse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    try {
      final json = jsonDecode(trimmed);
      if (json is! Map<String, dynamic>) {
        return null;
      }
      final userId = (json['user_id'] as String?)?.trim() ?? '';
      final serverUrl = (json['server_url'] as String?)?.trim() ?? '';
      if (userId.isEmpty || serverUrl.isEmpty) {
        return null;
      }
      return FriendQrPayload(userId: userId, serverUrl: serverUrl);
    } catch (_) {
      // Fallback: sync://friend?user_id=...&server_url=...
      final uri = Uri.tryParse(trimmed);
      if (uri == null || uri.scheme != 'sync' || uri.host != 'friend') {
        return null;
      }
      final userId = (uri.queryParameters['user_id'] ?? '').trim();
      final serverUrl = (uri.queryParameters['server_url'] ?? '').trim();
      if (userId.isEmpty || serverUrl.isEmpty) {
        return null;
      }
      return FriendQrPayload(userId: userId, serverUrl: serverUrl);
    }
  }
}
