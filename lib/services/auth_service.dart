import 'dart:convert';

import 'package:http/http.dart' as http;

class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;
}

class AuthService {
  Future<AuthTokens> login({
    required String baseUrl,
    required String email,
    required String password,
  }) async {
    final normalized = _normalizeBaseUrl(baseUrl);
    final uri = Uri.parse('$normalized/auth/login');
    final response = await http
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(const Duration(seconds: 8));

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

  String _normalizeBaseUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }
}
