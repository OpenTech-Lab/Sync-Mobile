import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'dev_http_client.dart';

class PlanetInfo {
  const PlanetInfo({
    required this.baseUrl,
    required this.host,
    required this.scheme,
    required this.instanceName,
    required this.instanceDescription,
    required this.instanceImageBase64,
    required this.instanceDomain,
    required this.countryCode,
    required this.countryName,
    required this.healthStatus,
    required this.latencyMs,
    required this.checkedAt,
  });

  final String baseUrl;
  final String host;
  final String scheme;
  final String? instanceName;
  final String? instanceDescription;
  final String? instanceImageBase64;
  final String? instanceDomain;
  final String? countryCode;
  final String? countryName;
  final String healthStatus;
  final int latencyMs;
  final DateTime checkedAt;
}

class ServerHealthService {
  ServerHealthService([http.Client? httpClient])
      : _httpClient = createDevHttpClient(httpClient);

  final http.Client _httpClient;

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
    final response = await _httpClient
        .get(uri)
        .timeout(const Duration(seconds: 5));
    final latencyMs = DateTime.now().difference(started).inMilliseconds;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Health check failed with status ${response.statusCode}.',
      );
    }

    var healthStatus = 'ok';
    String? instanceName;
    String? instanceDescription;
    String? instanceImageBase64;
    String? instanceDomain;
    String? countryCode;
    String? countryName;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final rawStatus = decoded['status'];
        if (rawStatus is String && rawStatus.trim().isNotEmpty) {
          healthStatus = rawStatus.trim();
        }
        final rawInstanceName = decoded['instance_name'];
        if (rawInstanceName is String && rawInstanceName.trim().isNotEmpty) {
          instanceName = rawInstanceName.trim();
        }
        final rawInstanceDescription = decoded['instance_description'];
        if (rawInstanceDescription is String &&
            rawInstanceDescription.trim().isNotEmpty) {
          instanceDescription = rawInstanceDescription.trim();
        }
        final rawInstanceImageBase64 = decoded['instance_image_base64'];
        if (rawInstanceImageBase64 is String &&
            rawInstanceImageBase64.trim().isNotEmpty) {
          instanceImageBase64 = rawInstanceImageBase64.trim();
        }
        final rawInstanceDomain = decoded['instance_domain'];
        if (rawInstanceDomain is String &&
            rawInstanceDomain.trim().isNotEmpty) {
          instanceDomain = rawInstanceDomain.trim();
        }
        final rawCountryCode = decoded['country_code'];
        if (rawCountryCode is String && rawCountryCode.trim().isNotEmpty) {
          countryCode = rawCountryCode.trim();
        }
        final rawCountryName = decoded['country_name'];
        if (rawCountryName is String && rawCountryName.trim().isNotEmpty) {
          countryName = rawCountryName.trim();
        }
      }
    } catch (_) {
      // Keep default "ok" if body is not parseable JSON.
    }

    return PlanetInfo(
      baseUrl: normalized,
      host: parsedBase.host,
      scheme: parsedBase.scheme,
      instanceName: instanceName,
      instanceDescription: instanceDescription,
      instanceImageBase64: instanceImageBase64,
      instanceDomain: instanceDomain,
      countryCode: countryCode,
      countryName: countryName,
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
