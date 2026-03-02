import 'dart:convert';

class JwtService {
  const JwtService();

  String? tryReadUserId(String accessToken) {
    try {
      final parts = accessToken.split('.');
      if (parts.length != 3) {
        return null;
      }

      final normalized = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final payload = jsonDecode(decoded) as Map<String, dynamic>;
      final sub = payload['sub'];
      if (sub is String && sub.isNotEmpty) {
        return sub;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
