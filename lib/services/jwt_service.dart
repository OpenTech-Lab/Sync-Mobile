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

  /// Returns true if the token is already expired or will expire within
  /// [bufferSeconds] (default 60 s). Treats unparseable tokens as expired.
  bool isExpiredOrExpiringSoon(String token, {int bufferSeconds = 60}) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final normalized = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final payload = jsonDecode(decoded) as Map<String, dynamic>;
      final exp = payload['exp'];
      if (exp is! int) return true;
      final expiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
      return DateTime.now().toUtc()
          .isAfter(expiry.subtract(Duration(seconds: bufferSeconds)));
    } catch (_) {
      return true;
    }
  }

  String? tryReadDisplayName(String accessToken) {
    try {
      final parts = accessToken.split('.');
      if (parts.length != 3) {
        return null;
      }

      final normalized = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final payload = jsonDecode(decoded) as Map<String, dynamic>;

      for (final key in ['username', 'preferred_username', 'name']) {
        final value = payload[key];
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
