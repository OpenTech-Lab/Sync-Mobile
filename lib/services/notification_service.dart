import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'dev_http_client.dart';

class NotificationService {
  NotificationService([FlutterSecureStorage? storage, http.Client? httpClient])
    : _storage = storage ?? const FlutterSecureStorage(),
      _httpClient = createDevHttpClient(httpClient);

  static const _deviceTokenKey = 'device_push_token';
  static const _channel = MethodChannel('sync.notifications');

  final FlutterSecureStorage _storage;
  final http.Client _httpClient;

  Future<void> initialize() async {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android)) {
      try {
        await _channel.invokeMethod<bool>('requestPushPermission');
      } catch (_) {}
    }
    await getOrCreateDeviceToken();
  }

  Future<String?> getOrCreateDeviceToken() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        final apnsToken = await _channel.invokeMethod<String>('getPushToken');
        if (apnsToken != null && apnsToken.trim().isNotEmpty) {
          final trimmed = apnsToken.trim();
          await _storage.write(key: _deviceTokenKey, value: trimmed);
          return trimmed;
        }
      } catch (_) {}
    }

    final existing = await _storage.read(key: _deviceTokenKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return null;
    }

    // Non-iOS fallback: keep deterministic local token so server-side webhook
    // integrations can still target non-APNS platforms when configured.
    final random = Random.secure();
    const chars = 'abcdef0123456789';
    final token = List.generate(
      48,
      (_) => chars[random.nextInt(chars.length)],
    ).join();

    await _storage.write(key: _deviceTokenKey, value: token);
    return token;
  }

  Future<void> syncTokenWithServer({
    required String baseUrl,
    required String accessToken,
  }) async {
    await initialize();
    final token = await getOrCreateDeviceToken();
    if (token == null || token.isEmpty) {
      return;
    }

    final uri = Uri.parse(baseUrl).replace(path: _pushPath(baseUrl));
    final response = await _httpClient
        .post(
          uri,
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({'token': token, 'platform': _platformName()}),
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Push token sync failed (${response.statusCode}).');
    }
  }

  Future<void> showIncomingMessageNotification({
    String? avatarBase64,
  }) async {
    if (kIsWeb) {
      return;
    }

    final normalizedAvatar = avatarBase64?.trim();

    try {
      await _channel.invokeMethod<void>('showLocalNotification', {
        'title': 'Sync',
        'body': 'New message',
        'avatarBase64':
            normalizedAvatar == null || normalizedAvatar.isEmpty
                ? null
                : normalizedAvatar,
      });
    } catch (_) {}
  }

  String _platformName() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'unknown';
    }
  }

  String _pushPath(String baseUrl) {
    final parsed = Uri.parse(baseUrl);
    final root = parsed.path.endsWith('/')
        ? parsed.path.substring(0, parsed.path.length - 1)
        : parsed.path;
    if (root.isEmpty || root == '/') {
      return '/api/push/token';
    }
    return '$root/api/push/token';
  }
}
