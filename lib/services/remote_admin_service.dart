import 'dart:convert';

import 'package:http/http.dart' as http;

import 'dev_http_client.dart';

class RemoteAdminApiException implements Exception {
  const RemoteAdminApiException(this.message, this.statusCode);

  final String message;
  final int statusCode;

  @override
  String toString() => message;
}

class AdminUser {
  const AdminUser({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
    required this.isActive,
    required this.isApproved,
    required this.createdAt,
    this.lastSeenAt,
    this.yellowCardExpiresAt,
    required this.yellowCardActive,
  });

  final String id;
  final String username;
  final String email;
  final String role;
  final bool isActive;
  final bool isApproved;
  final DateTime createdAt;
  final DateTime? lastSeenAt;
  final DateTime? yellowCardExpiresAt;
  final bool yellowCardActive;

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: (json['id'] as String?)?.trim() ?? '',
      username: (json['username'] as String?)?.trim() ?? '',
      email: (json['email'] as String?)?.trim() ?? '',
      role: (json['role'] as String?)?.trim() ?? 'user',
      isActive: (json['is_active'] as bool?) ?? true,
      isApproved: (json['is_approved'] as bool?) ?? true,
      createdAt:
          DateTime.tryParse(
            (json['created_at'] as String?)?.trim() ?? '',
          )?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      lastSeenAt: json['last_seen_at'] != null
          ? DateTime.tryParse(
              (json['last_seen_at'] as String).trim(),
            )?.toUtc()
          : null,
      yellowCardExpiresAt: json['yellow_card_expires_at'] != null
          ? DateTime.tryParse(
              (json['yellow_card_expires_at'] as String).trim(),
            )?.toUtc()
          : null,
      yellowCardActive: (json['yellow_card_active'] as bool?) ?? false,
    );
  }
}

class RemoteAdminService {
  RemoteAdminService([http.Client? httpClient])
    : _httpClient = createDevHttpClient(httpClient);

  final http.Client _httpClient;

  Future<List<AdminUser>> listUsers({
    required String baseUrl,
    required String accessToken,
    String? query,
  }) async {
    final normalized = _normalizeBaseUrl(baseUrl);
    final uri = Uri.parse('$normalized/api/admin/users').replace(
      queryParameters: query != null && query.trim().isNotEmpty
          ? {'q': query.trim()}
          : null,
    );
    final response = await _httpClient
        .get(uri, headers: _authHeaders(accessToken))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw _errorFromResponse(response, fallbackMessage: 'Failed to load users');
    }
    final json = jsonDecode(response.body) as List<dynamic>;
    return json
        .map((raw) => AdminUser.fromJson(raw as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> issueYellowCard({
    required String baseUrl,
    required String accessToken,
    required String userId,
  }) async {
    final response = await _post(
      baseUrl: baseUrl,
      accessToken: accessToken,
      path: '/api/admin/users/$userId/yellow-card',
      body: {},
    );
    if (response.statusCode != 200) {
      throw _errorFromResponse(response, fallbackMessage: 'Failed to issue yellow card');
    }
  }

  Future<void> clearYellowCard({
    required String baseUrl,
    required String accessToken,
    required String userId,
  }) async {
    final normalized = _normalizeBaseUrl(baseUrl);
    final uri = Uri.parse('$normalized/api/admin/users/$userId/yellow-card');
    final response = await _httpClient
        .delete(uri, headers: _authHeaders(accessToken))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw _errorFromResponse(response, fallbackMessage: 'Failed to clear yellow card');
    }
  }

  Future<void> suspendUser({
    required String baseUrl,
    required String accessToken,
    required String userId,
  }) async {
    final response = await _post(
      baseUrl: baseUrl,
      accessToken: accessToken,
      path: '/api/admin/users/$userId/suspend',
      body: {},
    );
    if (response.statusCode != 200) {
      throw _errorFromResponse(response, fallbackMessage: 'Failed to suspend user');
    }
  }

  Future<void> activateUser({
    required String baseUrl,
    required String accessToken,
    required String userId,
  }) async {
    final response = await _post(
      baseUrl: baseUrl,
      accessToken: accessToken,
      path: '/api/admin/users/$userId/activate',
      body: {},
    );
    if (response.statusCode != 200) {
      throw _errorFromResponse(response, fallbackMessage: 'Failed to activate user');
    }
  }

  Future<http.Response> _post({
    required String baseUrl,
    required String accessToken,
    required String path,
    required Map<String, dynamic> body,
  }) async {
    final normalized = _normalizeBaseUrl(baseUrl);
    final uri = Uri.parse('$normalized$path');
    return _httpClient
        .post(
          uri,
          headers: _authHeaders(accessToken),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));
  }

  RemoteAdminApiException _errorFromResponse(
    http.Response response, {
    required String fallbackMessage,
  }) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final message = (decoded['error'] as String?)?.trim();
        if (message != null && message.isNotEmpty) {
          return RemoteAdminApiException(message, response.statusCode);
        }
      }
    } catch (_) {}
    return RemoteAdminApiException(
      '$fallbackMessage (${response.statusCode}).',
      response.statusCode,
    );
  }

  Map<String, String> _authHeaders(String accessToken) {
    return {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    };
  }

  String _normalizeBaseUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }
}
