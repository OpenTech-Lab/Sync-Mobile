import 'dart:convert';

import 'package:http/http.dart' as http;

class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;
}

class AuthService {
  Future<void> register({
    required String baseUrl,
    required String username,
    required String email,
    required String password,
  }) async {
    final response = await _postAuth(
      baseUrl: baseUrl,
      path: 'register',
      body: {
        'username': username,
        'email': email,
        'password': password,
      },
    );

    if (response.statusCode != 201) {
      throw StateError('Sign up failed (${response.statusCode}).');
    }
  }

  Future<AuthTokens> login({
    required String baseUrl,
    required String email,
    required String password,
  }) async {
    final response = await _postAuth(
      baseUrl: baseUrl,
      path: 'login',
      body: {'email': email, 'password': password},
    );

    if (response.statusCode != 200) {
      throw StateError('Login failed (${response.statusCode}).');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final accessToken = json['access_token'] as String?;
    final refreshToken = json['refresh_token'] as String?;

    if (accessToken == null || refreshToken == null) {
      throw const FormatException('Invalid login response.');
    }

    return AuthTokens(accessToken: accessToken, refreshToken: refreshToken);
  }

  Future<AuthTokens> refresh({
    required String baseUrl,
    required String refreshToken,
  }) async {
    final response = await _postAuth(
      baseUrl: baseUrl,
      path: 'refresh',
      body: {'refresh_token': refreshToken},
    );

    if (response.statusCode != 200) {
      throw StateError('Token refresh failed (${response.statusCode}).');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final accessToken = json['access_token'] as String?;
    final newRefreshToken = json['refresh_token'] as String?;

    if (accessToken == null || newRefreshToken == null) {
      throw const FormatException('Invalid refresh response.');
    }

    return AuthTokens(accessToken: accessToken, refreshToken: newRefreshToken);
  }

  String _normalizeBaseUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  String _stripApiSuffix(String baseUrl) {
    if (baseUrl.endsWith('/api')) {
      return baseUrl.substring(0, baseUrl.length - 4);
    }
    return baseUrl;
  }

  Future<void> forgotPassword({
    required String baseUrl,
    required String email,
  }) async {
    final normalized = _normalizeBaseUrl(baseUrl);
    final uri = Uri.parse('$normalized/auth/forgot-password');
    final response = await http
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email.trim().toLowerCase()}),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw StateError('Request failed (${response.statusCode}).');
    }
  }

  Future<http.Response> _postAuth({
    required String baseUrl,
    required String path,
    required Map<String, String> body,
  }) async {
    final normalized = _normalizeBaseUrl(baseUrl);
    final firstUri = Uri.parse('$normalized/auth/$path');

    var response = await http
        .post(
          firstUri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 404 && normalized.endsWith('/api')) {
      final fallbackBase = _stripApiSuffix(normalized);
      final fallbackUri = Uri.parse('$fallbackBase/auth/$path');
      response = await http
          .post(
            fallbackUri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 8));
    }

    return response;
  }
}
