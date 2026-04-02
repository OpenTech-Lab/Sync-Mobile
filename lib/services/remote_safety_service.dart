import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/user_profile.dart';
import 'dev_http_client.dart';

class RemoteSafetyApiException implements Exception {
  const RemoteSafetyApiException(this.message, this.statusCode);

  final String message;
  final int statusCode;

  @override
  String toString() => message;
}

class BlockedUser {
  const BlockedUser({
    required this.userId,
    required this.username,
    required this.avatarBase64,
    required this.blockedAt,
  });

  final String userId;
  final String username;
  final String? avatarBase64;
  final DateTime blockedAt;

  factory BlockedUser.fromJson(Map<String, dynamic> json) {
    return BlockedUser(
      userId: (json['user_id'] as String?)?.trim() ?? '',
      username: (json['username'] as String?)?.trim() ?? '',
      avatarBase64: (json['avatar_base64'] as String?)?.trim(),
      blockedAt:
          DateTime.tryParse(
            (json['blocked_at'] as String?)?.trim() ?? '',
          )?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}

class RemoteSafetyService {
  RemoteSafetyService([http.Client? httpClient])
    : _httpClient = createDevHttpClient(httpClient);

  final http.Client _httpClient;

  Future<UserSafetyState> acceptTerms({
    required String baseUrl,
    required String accessToken,
    required int acceptedTermsVersion,
  }) async {
    final response = await _post(
      baseUrl: baseUrl,
      accessToken: accessToken,
      path: '/api/safety/accept-terms',
      body: {'accepted_terms_version': acceptedTermsVersion},
    );
    if (response.statusCode != 200) {
      throw _errorFromResponse(
        response,
        fallbackMessage: 'Failed to accept terms',
      );
    }
    return UserSafetyState.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<BlockedUser>> listBlockedUsers({
    required String baseUrl,
    required String accessToken,
  }) async {
    final normalized = _normalizeBaseUrl(baseUrl);
    final uri = Uri.parse('$normalized/api/safety/blocks');
    final response = await _httpClient
        .get(uri, headers: _authHeaders(accessToken))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw _errorFromResponse(
        response,
        fallbackMessage: 'Failed to load blocked users',
      );
    }
    final json = jsonDecode(response.body) as List<dynamic>;
    return json
        .map((raw) => BlockedUser.fromJson(raw as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<BlockedUser> blockUser({
    required String baseUrl,
    required String accessToken,
    required String userId,
    String? reasonCode,
    String? reporterNote,
  }) async {
    final response = await _post(
      baseUrl: baseUrl,
      accessToken: accessToken,
      path: '/api/safety/blocks',
      body: {
        'user_id': userId,
        if (reasonCode != null && reasonCode.trim().isNotEmpty)
          'reason_code': reasonCode.trim(),
        if (reporterNote != null && reporterNote.trim().isNotEmpty)
          'reporter_note': reporterNote.trim(),
      },
    );
    if (response.statusCode != 201) {
      throw _errorFromResponse(
        response,
        fallbackMessage: 'Failed to block user',
      );
    }
    return BlockedUser.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<void> unblockUser({
    required String baseUrl,
    required String accessToken,
    required String userId,
  }) async {
    final normalized = _normalizeBaseUrl(baseUrl);
    final uri = Uri.parse('$normalized/api/safety/blocks/$userId');
    final response = await _httpClient
        .delete(uri, headers: _authHeaders(accessToken))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 204) {
      throw _errorFromResponse(
        response,
        fallbackMessage: 'Failed to unblock user',
      );
    }
  }

  Future<void> reportUserProfile({
    required String baseUrl,
    required String accessToken,
    required String reportedUserId,
    required String reasonCode,
    String? reporterNote,
  }) async {
    final response = await _post(
      baseUrl: baseUrl,
      accessToken: accessToken,
      path: '/api/safety/reports',
      body: {
        'reported_user_id': reportedUserId,
        'source': 'user_report',
        'content_kind': 'user_profile',
        'reason_code': reasonCode,
        if (reporterNote != null && reporterNote.trim().isNotEmpty)
          'reporter_note': reporterNote.trim(),
      },
    );
    if (response.statusCode != 201) {
      throw _errorFromResponse(
        response,
        fallbackMessage: 'Failed to submit report',
      );
    }
  }

  Future<void> reportMessage({
    required String baseUrl,
    required String accessToken,
    required String reportedUserId,
    required String contentKind,
    required String contentId,
    required String messageText,
    required String reasonCode,
    String? reporterNote,
  }) async {
    final response = await _post(
      baseUrl: baseUrl,
      accessToken: accessToken,
      path: '/api/safety/reports',
      body: {
        'reported_user_id': reportedUserId,
        'source': 'user_report',
        'content_kind': contentKind,
        'content_id': contentId,
        'reason_code': reasonCode,
        'content_excerpt_override': messageText,
        if (reporterNote != null && reporterNote.trim().isNotEmpty)
          'reporter_note': reporterNote.trim(),
      },
    );
    if (response.statusCode != 201) {
      throw _errorFromResponse(
        response,
        fallbackMessage: 'Failed to submit message report',
      );
    }
  }

  Future<http.Response> _post({
    required String baseUrl,
    required String accessToken,
    required String path,
    required Map<String, dynamic> body,
  }) {
    final normalized = _normalizeBaseUrl(baseUrl);
    final uri = Uri.parse('$normalized$path');
    return _httpClient
        .post(uri, headers: _authHeaders(accessToken), body: jsonEncode(body))
        .timeout(const Duration(seconds: 10));
  }

  RemoteSafetyApiException _errorFromResponse(
    http.Response response, {
    required String fallbackMessage,
  }) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final message = (decoded['error'] as String?)?.trim();
        if (message != null && message.isNotEmpty) {
          return RemoteSafetyApiException(message, response.statusCode);
        }
      }
    } catch (_) {}
    return RemoteSafetyApiException(
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
