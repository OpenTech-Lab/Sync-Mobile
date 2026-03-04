import 'dart:convert';

import 'package:http/http.dart' as http;

import 'dev_http_client.dart';

class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;
}

class QrLoginSession {
  const QrLoginSession({
    required this.sessionId,
    required this.qrPayload,
    required this.expiresIn,
  });

  final String sessionId;
  final String qrPayload;
  final int expiresIn;
}

class QrLoginStatus {
  const QrLoginStatus({
    required this.status,
    this.accessToken,
    this.refreshToken,
  });

  final String status;
  final String? accessToken;
  final String? refreshToken;

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isExpired => status == 'expired';
}

class AuthService {
  AuthService([http.Client? httpClient])
    : _httpClient = createDevHttpClient(httpClient);

  final http.Client _httpClient;

  Future<void> register({
    required String baseUrl,
    required String username,
    required String email,
    required String password,
  }) async {
    final response = await _postAuth(
      baseUrl: baseUrl,
      path: 'register',
      body: {'username': username, 'email': email, 'password': password},
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

  Future<QrLoginSession> createQrLoginSession({required String baseUrl}) async {
    final response = await _postAuth(
      baseUrl: baseUrl,
      path: 'qr-login/session',
      body: const <String, String>{},
    );
    if (response.statusCode != 201) {
      throw StateError('QR session creation failed (${response.statusCode}).');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final sessionId = json['session_id'] as String?;
    final qrPayload = json['qr_payload'] as String?;
    final expiresIn = json['expires_in'] as int?;
    if (sessionId == null || qrPayload == null || expiresIn == null) {
      throw const FormatException('Invalid QR login session response.');
    }
    return QrLoginSession(
      sessionId: sessionId,
      qrPayload: qrPayload,
      expiresIn: expiresIn,
    );
  }

  Future<QrLoginStatus> pollQrLoginSession({
    required String baseUrl,
    required String sessionId,
    required String secret,
  }) async {
    final normalized = _normalizeBaseUrl(baseUrl);
    final uri = Uri.parse(
      '$normalized/auth/qr-login/session/$sessionId?secret=${Uri.encodeQueryComponent(secret)}',
    );
    var response = await _httpClient
        .get(uri)
        .timeout(const Duration(seconds: 8));
    if (response.statusCode == 404 && normalized.endsWith('/api')) {
      final fallbackBase = _stripApiSuffix(normalized);
      final fallbackUri = Uri.parse(
        '$fallbackBase/auth/qr-login/session/$sessionId?secret=${Uri.encodeQueryComponent(secret)}',
      );
      response = await _httpClient
          .get(fallbackUri)
          .timeout(const Duration(seconds: 8));
    }
    if (response.statusCode != 200) {
      throw StateError('QR login polling failed (${response.statusCode}).');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final status = json['status'] as String?;
    if (status == null) {
      throw const FormatException('Invalid QR login status response.');
    }
    return QrLoginStatus(
      status: status,
      accessToken: json['access_token'] as String?,
      refreshToken: json['refresh_token'] as String?,
    );
  }

  Future<void> approveQrLoginSession({
    required String baseUrl,
    required String accessToken,
    required String sessionId,
    required String secret,
  }) async {
    final normalized = _normalizeBaseUrl(baseUrl);
    final uri = Uri.parse('$normalized/auth/qr-login/approve');
    var response = await _httpClient
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
          body: jsonEncode({'session_id': sessionId, 'secret': secret}),
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode == 404 && normalized.endsWith('/api')) {
      final fallbackBase = _stripApiSuffix(normalized);
      final fallbackUri = Uri.parse('$fallbackBase/auth/qr-login/approve');
      response = await _httpClient
          .post(
            fallbackUri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $accessToken',
            },
            body: jsonEncode({'session_id': sessionId, 'secret': secret}),
          )
          .timeout(const Duration(seconds: 8));
    }
    if (response.statusCode != 200) {
      throw StateError('QR login approval failed (${response.statusCode}).');
    }
  }

  Future<String?> fetchMyEmail({
    required String baseUrl,
    required String accessToken,
  }) async {
    final normalized = _normalizeBaseUrl(baseUrl);
    final uri = Uri.parse('$normalized/auth/me');
    var response = await _httpClient
        .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
        .timeout(const Duration(seconds: 8));
    if (response.statusCode == 404 && normalized.endsWith('/api')) {
      final fallbackBase = _stripApiSuffix(normalized);
      final fallbackUri = Uri.parse('$fallbackBase/auth/me');
      response = await _httpClient
          .get(fallbackUri, headers: {'Authorization': 'Bearer $accessToken'})
          .timeout(const Duration(seconds: 8));
    }
    if (response.statusCode != 200) {
      return null;
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return (json['email'] as String?)?.trim().toLowerCase();
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
    final response = await _httpClient
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

    var response = await _httpClient
        .post(
          firstUri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 404 && normalized.endsWith('/api')) {
      final fallbackBase = _stripApiSuffix(normalized);
      final fallbackUri = Uri.parse('$fallbackBase/auth/$path');
      response = await _httpClient
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
