import 'dart:convert';

import 'package:http/http.dart' as http;

import 'dev_http_client.dart';

class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;
}

class DeviceLoginChallenge {
  const DeviceLoginChallenge({
    required this.challengeId,
    required this.serverEphemeralPublicKey,
    required this.expiresIn,
  });

  final String challengeId;
  final String serverEphemeralPublicKey;
  final int expiresIn;
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

class AccountPendingApprovalException implements Exception {
  const AccountPendingApprovalException([this.message]);
  final String? message;
  @override
  String toString() => message ?? 'Account pending admin approval';
}

class AuthService {
  AuthService([http.Client? httpClient])
    : _httpClient = createDevHttpClient(httpClient);

  final http.Client _httpClient;

  /// Requests a device-login challenge. Returns `null` only when the server has
  /// no challenge endpoint (404/405, after the `/api` root retry in
  /// [_postAuth]), i.e. it predates the challenge. Every other failure throws.
  Future<DeviceLoginChallenge?> _requestDeviceLoginChallenge({
    required String baseUrl,
    required String deviceAuthPublicKey,
  }) async {
    final response = await _postAuth(
      baseUrl: baseUrl,
      path: 'device-login/challenge',
      body: {'device_auth_pubkey': deviceAuthPublicKey},
    );
    if (_isEndpointMissing(response)) {
      return null;
    }
    if (response.statusCode != 200) {
      throw StateError(
        'Device login challenge failed (${response.statusCode}).',
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const FormatException('Invalid device login challenge response.');
    }
    final json = decoded is Map<String, dynamic> ? decoded : null;
    final challengeId = json?['challenge_id'];
    final serverPublicKey = json?['server_ephemeral_pubkey'];
    final expiresIn = json?['expires_in'];
    if (challengeId is! String ||
        serverPublicKey is! String ||
        expiresIn is! int) {
      throw const FormatException('Invalid device login challenge response.');
    }
    return DeviceLoginChallenge(
      challengeId: challengeId,
      serverEphemeralPublicKey: serverPublicKey,
      expiresIn: expiresIn,
    );
  }

  /// Logs in with the device key. Uses the device-login challenge when the
  /// server supports it: [createProof] is called with the challenge and its
  /// result is sent as `proof` next to `challenge_id`. A server that has no
  /// challenge endpoint gets the legacy body instead; any other challenge
  /// failure is an error, and a legacy body is never sent after a challenge
  /// was issued.
  Future<AuthTokens> deviceLogin({
    required String baseUrl,
    required String deviceAuthPublicKey,
    required Future<String> Function(DeviceLoginChallenge challenge)
    createProof,
    String? altchaPayload,
    int? acceptedTermsVersion,
  }) async {
    final challenge = await _requestDeviceLoginChallenge(
      baseUrl: baseUrl,
      deviceAuthPublicKey: deviceAuthPublicKey,
    );
    final body = <String, dynamic>{'device_auth_pubkey': deviceAuthPublicKey};
    if (challenge != null) {
      body['challenge_id'] = challenge.challengeId;
      body['proof'] = await createProof(challenge);
    }
    if (altchaPayload != null) {
      body['altcha_payload'] = altchaPayload;
    }
    if (acceptedTermsVersion != null) {
      body['accepted_terms_version'] = acceptedTermsVersion;
    }

    final response = await _postAuth(
      baseUrl: baseUrl,
      path: 'device-login',
      body: body,
    );

    if (response.statusCode == 202) {
      // Account created but pending admin approval.
      throw const AccountPendingApprovalException(
        'Your account has been created and is awaiting admin approval. '
        'You\'ll be able to log in once an admin reviews your request.',
      );
    }
    if (response.statusCode == 403) {
      throw const AccountPendingApprovalException(
        'Your account is pending admin approval. '
        'Please wait for an admin to review your request.',
      );
    }
    if (response.statusCode != 200) {
      throw StateError('Device login failed (${response.statusCode}).');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final accessToken = json['access_token'] as String?;
    final refreshToken = json['refresh_token'] as String?;

    if (accessToken == null || refreshToken == null) {
      throw const FormatException('Invalid device login response.');
    }

    return AuthTokens(accessToken: accessToken, refreshToken: refreshToken);
  }

  Future<void> register({
    required String baseUrl,
    required String username,
    required String email,
    required String password,
    String? altchaPayload,
    int? acceptedTermsVersion,
  }) async {
    final body = <String, dynamic>{
      'username': username,
      'email': email,
      'password': password,
    };
    if (altchaPayload != null) {
      body['altcha_payload'] = altchaPayload;
    }
    if (acceptedTermsVersion != null) {
      body['accepted_terms_version'] = acceptedTermsVersion;
    }

    final response = await _postAuth(
      baseUrl: baseUrl,
      path: 'register',
      body: body,
    );

    if (response.statusCode != 201) {
      throw StateError('Sign up failed (${response.statusCode}).');
    }
  }

  Future<AuthTokens> login({
    required String baseUrl,
    required String email,
    required String password,
    String? altchaPayload,
    int? acceptedTermsVersion,
  }) async {
    final body = <String, dynamic>{'email': email, 'password': password};
    if (altchaPayload != null) {
      body['altcha_payload'] = altchaPayload;
    }
    if (acceptedTermsVersion != null) {
      body['accepted_terms_version'] = acceptedTermsVersion;
    }

    final response = await _postAuth(
      baseUrl: baseUrl,
      path: 'login',
      body: body,
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

  /// Polls a QR login session. The secret travels in a POST body; only a server
  /// that has no such route (404/405, after the `/api` root retry) is polled
  /// with the legacy `GET ?secret=` form. Other failures are errors.
  Future<QrLoginStatus> pollQrLoginSession({
    required String baseUrl,
    required String sessionId,
    required String secret,
  }) async {
    final normalized = _normalizeBaseUrl(baseUrl);
    Future<http.Response> post(String base) => _httpClient
        .post(
          Uri.parse('$base/auth/qr-login/session/$sessionId'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'secret': secret}),
        )
        .timeout(const Duration(seconds: 8));
    Future<http.Response> get(String base) => _httpClient
        .get(
          Uri.parse(
            '$base/auth/qr-login/session/$sessionId'
            '?secret=${Uri.encodeQueryComponent(secret)}',
          ),
        )
        .timeout(const Duration(seconds: 8));

    var response = await post(normalized);
    if (response.statusCode == 404 && normalized.endsWith('/api')) {
      response = await post(_stripApiSuffix(normalized));
    }
    if (_isEndpointMissing(response)) {
      try {
        response = await get(normalized);
        if (response.statusCode == 404 && normalized.endsWith('/api')) {
          response = await get(_stripApiSuffix(normalized));
        }
      } catch (error) {
        // Transport errors quote the request URL, which carries the secret.
        throw StateError('QR login polling failed: ${_redactedError(error)}');
      }
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

  /// 404/405 means the route does not exist on this server (it predates the
  /// endpoint), as opposed to the endpoint rejecting the request.
  bool _isEndpointMissing(http.Response response) =>
      response.statusCode == 404 || response.statusCode == 405;

  /// Error text that is safe to surface: strips a `?secret=` / `&secret=` value
  /// that transport errors quote from the request URL.
  static String _redactedError(Object error) =>
      error.toString().replaceAllMapped(
        RegExp(r'([?&]secret=)[^&\s\x27"#]*'),
        (m) => '${m[1]}<redacted>',
      );

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

  /// Fetches an ALTCHA challenge from the server.
  ///
  /// Returns the raw challenge JSON map when ALTCHA is enabled, or `null` when
  /// ALTCHA is disabled on the server (HTTP 404) or the request fails (network
  /// error, unexpected status). Callers should proceed without a payload when
  /// this returns `null`.
  Future<Map<String, dynamic>?> fetchAltchaChallenge(String baseUrl) async {
    final normalized = _normalizeBaseUrl(baseUrl);
    final candidates = _candidateAuthBaseUrls(normalized);

    for (final candidate in candidates) {
      try {
        final uri = Uri.parse('$candidate/auth/altcha');
        final response = await _httpClient
            .get(uri, headers: const {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 8));

        if (response.statusCode == 404) {
          // ALTCHA is not configured on this server.
          return null;
        }
        if (response.statusCode == 200) {
          return jsonDecode(response.body) as Map<String, dynamic>;
        }
        // Unexpected status – try next candidate.
      } catch (_) {
        // Network error – try next candidate.
      }
    }
    // All candidates failed – treat as disabled to avoid hard-blocking login.
    return null;
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
    required Map<String, dynamic> body,
  }) async {
    final normalized = _normalizeBaseUrl(baseUrl);
    final candidates = _candidateAuthBaseUrls(normalized);
    Object? lastError;
    http.Response? lastResponse;

    for (final candidate in candidates) {
      try {
        final uri = Uri.parse('$candidate/auth/$path');
        final response = await _httpClient
            .post(
              uri,
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 8));
        if (response.statusCode == 404) {
          lastResponse = response;
          continue;
        }
        return response;
      } catch (error) {
        lastError = error;
      }
    }

    final response = lastResponse;
    if (response != null) {
      return response;
    }

    final parsed = Uri.tryParse(normalized);
    final host = parsed?.host.toLowerCase();
    if (host == 'localhost' || host == '127.0.0.1' || host == '::1') {
      throw StateError(
        'Local auth connection failed. Try http://10.0.2.2:8080 (or 10.0.3.2:8080) on Android emulator, or include explicit local server port.',
      );
    }

    throw StateError('Auth request failed: $lastError');
  }

  List<String> _candidateAuthBaseUrls(String normalizedBaseUrl) {
    final candidates = <String>[];

    void push(String value) {
      final normalized = _normalizeBaseUrl(value);
      if (normalized.isNotEmpty && !candidates.contains(normalized)) {
        candidates.add(normalized);
      }
    }

    push(normalizedBaseUrl);
    final apiStripped = _stripApiSuffix(normalizedBaseUrl);
    if (apiStripped != normalizedBaseUrl) {
      push(apiStripped);
    }

    final parsed = Uri.tryParse(normalizedBaseUrl);
    if (parsed == null) {
      return candidates;
    }

    final host = parsed.host.toLowerCase();
    final isLocalHost =
        host == 'localhost' || host == '127.0.0.1' || host == '::1';
    if (!isLocalHost) {
      return candidates;
    }

    if (parsed.scheme == 'https') {
      push(parsed.replace(scheme: 'http').toString());
    }

    if (!parsed.hasPort) {
      push(parsed.replace(scheme: 'http', port: 8080).toString());
      push(parsed.replace(scheme: 'http', port: 80).toString());
    }

    final emulatorHosts = ['10.0.2.2', '10.0.3.2'];
    for (final emulatorHost in emulatorHosts) {
      push(parsed.replace(host: emulatorHost, scheme: 'http').toString());
      if (!parsed.hasPort) {
        push(
          parsed
              .replace(host: emulatorHost, scheme: 'http', port: 8080)
              .toString(),
        );
        push(
          parsed
              .replace(host: emulatorHost, scheme: 'http', port: 80)
              .toString(),
        );
      }
    }
    return candidates;
  }
}
