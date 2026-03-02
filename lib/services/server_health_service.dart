import 'dart:async';

import 'package:http/http.dart' as http;

class ServerHealthService {
  Future<void> validate(String baseUrl) async {
    final normalized = _normalizeBaseUrl(baseUrl);
    final uri = Uri.tryParse('$normalized/health');
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      throw const FormatException('Enter a valid http(s) server URL.');
    }

    final response = await http.get(uri).timeout(const Duration(seconds: 5));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Health check failed with status ${response.statusCode}.');
    }
  }

  String _normalizeBaseUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }
}
