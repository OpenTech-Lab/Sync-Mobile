import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class PlanetInfo {
  const PlanetInfo({
    required this.baseUrl,
    required this.host,
    required this.scheme,
    required this.healthStatus,
    required this.latencyMs,
    required this.checkedAt,
  });

  final String baseUrl;
  final String host;
  final String scheme;
  final String healthStatus;
  final int latencyMs;
  final DateTime checkedAt;
}

class ServerHealthService {
  Future<PlanetInfo> validate(String baseUrl) async {
    final normalized = _normalizeBaseUrl(baseUrl);
    final parsedBase = Uri.tryParse(normalized);
    final uri = Uri.tryParse('$normalized/health');
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      throw const FormatException('Enter a valid http(s) server URL.');
    }
    if (parsedBase == null || parsedBase.host.trim().isEmpty) {
      throw const FormatException('Enter a valid server URL host.');
    }

    final started = DateTime.now();
    final response = await http.get(uri).timeout(const Duration(seconds: 5));
    final latencyMs = DateTime.now().difference(started).inMilliseconds;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Health check failed with status ${response.statusCode}.',
      );
    }

    var healthStatus = 'ok';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final rawStatus = decoded['status'];
        if (rawStatus is String && rawStatus.trim().isNotEmpty) {
          healthStatus = rawStatus.trim();
        }
      }
    } catch (_) {
      // Keep default "ok" if body is not parseable JSON.
    }

    return PlanetInfo(
      baseUrl: normalized,
      host: parsedBase.host,
      scheme: parsedBase.scheme,
      healthStatus: healthStatus,
      latencyMs: latencyMs,
      checkedAt: DateTime.now(),
    );
  }

  String _normalizeBaseUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }
}
