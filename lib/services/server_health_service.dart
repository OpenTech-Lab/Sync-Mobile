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
    required this.instanceImageUrl,
    required this.memberCount,
    required this.linkedPlanets,
    required this.instanceDomain,
    required this.countryCode,
    required this.countryName,
    required this.serverCreatedAt,
    required this.healthStatus,
    required this.latencyMs,
    required this.checkedAt,
  });

  final String baseUrl;
  final String host;
  final String scheme;
  final String? instanceName;
  final String? instanceDescription;
  final String? instanceImageUrl;
  final int? memberCount;
  final List<String> linkedPlanets;
  final String? instanceDomain;
  final String? countryCode;
  final String? countryName;
  final DateTime? serverCreatedAt;
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
    if (parsedBase == null ||
        !(parsedBase.scheme == 'http' || parsedBase.scheme == 'https')) {
      throw const FormatException('Enter a valid http(s) server URL.');
    }
    if (parsedBase.host.trim().isEmpty) {
      throw const FormatException('Enter a valid server URL host.');
    }

    final candidates = _candidateBaseUrls(parsedBase);
    Object? lastError;
    for (final candidateBase in candidates) {
      final candidateParsed = Uri.tryParse(candidateBase);
      final uri = Uri.tryParse('$candidateBase/health');
      if (candidateParsed == null || uri == null) {
        continue;
      }
      try {
        final started = DateTime.now();
        final response = await _httpClient
            .get(uri)
            .timeout(const Duration(seconds: 5));
        final latencyMs = DateTime.now().difference(started).inMilliseconds;
        if (response.statusCode < 200 || response.statusCode >= 300) {
          lastError = StateError(
            'Health check failed with status ${response.statusCode}.',
          );
          continue;
        }

        var healthStatus = 'ok';
        String? instanceName;
        String? instanceDescription;
        String? instanceImageUrl;
        int? memberCount;
        List<String> linkedPlanets = const [];
        String? instanceDomain;
        String? countryCode;
        String? countryName;
        DateTime? serverCreatedAt;
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            final rawStatus = decoded['status'];
            if (rawStatus is String && rawStatus.trim().isNotEmpty) {
              healthStatus = rawStatus.trim();
            }
            final rawInstanceName = decoded['instance_name'];
            if (rawInstanceName is String &&
                rawInstanceName.trim().isNotEmpty) {
              instanceName = rawInstanceName.trim();
            }
            final rawInstanceDescription = decoded['instance_description'];
            if (rawInstanceDescription is String &&
                rawInstanceDescription.trim().isNotEmpty) {
              instanceDescription = rawInstanceDescription.trim();
            }
            final rawInstanceImageUrl = decoded['instance_image_url'];
            if (rawInstanceImageUrl is String &&
                rawInstanceImageUrl.trim().isNotEmpty) {
              instanceImageUrl = rawInstanceImageUrl.trim();
            }
            final rawMemberCount = decoded['member_count'];
            if (rawMemberCount is int && rawMemberCount >= 0) {
              memberCount = rawMemberCount;
            }
            final rawLinkedPlanets = decoded['linked_planets'];
            if (rawLinkedPlanets is List) {
              linkedPlanets = rawLinkedPlanets
                  .whereType<String>()
                  .map((item) => item.trim())
                  .where((item) => item.isNotEmpty)
                  .toList(growable: false);
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
            final rawServerCreatedAt = decoded['server_created_at'];
            if (rawServerCreatedAt is String &&
                rawServerCreatedAt.trim().isNotEmpty) {
              serverCreatedAt = DateTime.tryParse(
                rawServerCreatedAt.trim(),
              )?.toUtc();
            }
          }
        } catch (_) {
          // Keep default "ok" if body is not parseable JSON.
        }

        return PlanetInfo(
          baseUrl: candidateBase,
          host: candidateParsed.host,
          scheme: candidateParsed.scheme,
          instanceName: instanceName,
          instanceDescription: instanceDescription,
          instanceImageUrl: instanceImageUrl,
          memberCount: memberCount,
          linkedPlanets: linkedPlanets,
          instanceDomain: instanceDomain,
          countryCode: countryCode,
          countryName: countryName,
          serverCreatedAt: serverCreatedAt,
          healthStatus: healthStatus,
          latencyMs: latencyMs,
          checkedAt: DateTime.now(),
        );
      } catch (error) {
        lastError = error;
      }
    }

    if (parsedBase.host.toLowerCase() == 'localhost' ||
        parsedBase.host == '127.0.0.1' ||
        parsedBase.host == '::1') {
      throw StateError(
        'Local server unreachable. Try http://10.0.2.2:8080 (or 10.0.3.2:8080) on Android emulator, or include an explicit local server port.',
      );
    }
    throw StateError('Connection failed: $lastError');
  }

  String _normalizeBaseUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  List<String> _candidateBaseUrls(Uri base) {
    final candidates = <String>[];

    void push(Uri uri) {
      final value = _normalizeBaseUrl(uri.toString());
      if (value.isNotEmpty && !candidates.contains(value)) {
        candidates.add(value);
      }
    }

    push(base);

    final host = base.host.toLowerCase();
    final isLocalHost =
        host == 'localhost' || host == '127.0.0.1' || host == '::1';
    if (!isLocalHost) {
      return candidates;
    }

    if (base.scheme == 'https') {
      push(base.replace(scheme: 'http'));
    }

    if (!base.hasPort) {
      push(base.replace(scheme: 'http', port: 8080));
      push(base.replace(scheme: 'http', port: 80));
    }

    final emulatorHosts = ['10.0.2.2', '10.0.3.2'];
    for (final emulatorHost in emulatorHosts) {
      push(base.replace(host: emulatorHost, scheme: 'http'));
      if (!base.hasPort) {
        push(base.replace(host: emulatorHost, scheme: 'http', port: 8080));
        push(base.replace(host: emulatorHost, scheme: 'http', port: 80));
      }
    }

    return candidates;
  }
}
