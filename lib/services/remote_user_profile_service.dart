import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/user_profile.dart';

class RemoteUserProfileService {
  RemoteUserProfileService([http.Client? httpClient])
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  Future<UserProfile> getMyProfile({
    required String baseUrl,
    required String accessToken,
  }) async {
    final normalized = _normalizeBaseUrl(baseUrl);
    final uri = Uri.parse('$normalized/api/profile/me');

    final response = await _httpClient
        .get(uri, headers: _authHeaders(accessToken))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw StateError('Failed to load profile (${response.statusCode}).');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return UserProfile.fromJson(json);
  }

  Future<UserProfile> getUserProfile({
    required String baseUrl,
    required String accessToken,
    required String userId,
  }) async {
    final normalized = _normalizeBaseUrl(baseUrl);
    final uri = Uri.parse('$normalized/api/profile/$userId');

    final response = await _httpClient
        .get(uri, headers: _authHeaders(accessToken))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw StateError('Failed to load user profile (${response.statusCode}).');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return UserProfile.fromJson(json);
  }

  Future<UserProfile> updateMyProfile({
    required String baseUrl,
    required String accessToken,
    String? username,
    String? avatarBase64,
    bool clearAvatar = false,
  }) async {
    final normalized = _normalizeBaseUrl(baseUrl);
    final uri = Uri.parse('$normalized/api/profile/me');

    final body = <String, dynamic>{};
    final normalizedUsername = username?.trim();
    final normalizedAvatar = avatarBase64?.trim();

    if (normalizedUsername != null && normalizedUsername.isNotEmpty) {
      body['username'] = normalizedUsername;
    }
    if (clearAvatar) {
      body['avatar_base64'] = null;
    } else if (normalizedAvatar != null && normalizedAvatar.isNotEmpty) {
      body['avatar_base64'] = normalizedAvatar;
    }

    final response = await _httpClient
        .patch(
          uri,
          headers: _authHeaders(accessToken),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) {
      throw StateError('Failed to update profile (${response.statusCode}).');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return UserProfile.fromJson(json);
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
