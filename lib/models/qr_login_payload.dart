import 'dart:convert';

class QrLoginPayload {
  const QrLoginPayload({required this.sessionId, required this.secret});

  final String sessionId;
  final String secret;

  static QrLoginPayload? tryParse(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      if (decoded['type'] != 'sync_qr_login') {
        return null;
      }
      final sessionId = (decoded['session_id'] as String?)?.trim() ?? '';
      final secret = (decoded['secret'] as String?)?.trim() ?? '';
      if (sessionId.isEmpty || secret.isEmpty) {
        return null;
      }
      return QrLoginPayload(sessionId: sessionId, secret: secret);
    } catch (_) {
      return null;
    }
  }
}
