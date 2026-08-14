import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'app_secure_storage.dart';
import 'dev_http_client.dart';

class NotificationService {
  NotificationService([AppSecureStorage? storage, http.Client? httpClient])
    : _storage = storage ?? const AppSecureStorage(),
      _httpClient = createDevHttpClient(httpClient);

  static const _deviceTokenKey = 'device_push_token';
  static const _voipTokenKey = 'device_voip_push_token';
  static const _channel = MethodChannel('sync.notifications');

  final AppSecureStorage _storage;
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
      // APNs token registration is asynchronous: registerForRemoteNotifications()
      // fires in Swift but the callback may arrive seconds later. Poll briefly
      // so the token is available on the very first launch before we sync it
      // to the server. Subsequent launches hit UserDefaults immediately.
      for (var attempt = 0; attempt < 6; attempt++) {
        try {
          final apnsToken = await _channel.invokeMethod<String>('getPushToken');
          if (apnsToken != null && apnsToken.trim().isNotEmpty) {
            final trimmed = apnsToken.trim();
            await _storage.write(key: _deviceTokenKey, value: trimmed);
            return trimmed;
          }
        } catch (_) {}
        if (attempt < 5) await Future.delayed(const Duration(seconds: 1));
      }
    }

    final existing = await _storage.read(key: _deviceTokenKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    // Android has no real push transport yet (FCM integration is Phase 2),
    // so there is no token to hand back. Returning a synthetic value here
    // previously let the app believe push was configured when it wasn't.
    return null;
  }

  /// Retrieves (or waits briefly for) the device's PushKit VoIP token.
  ///
  /// Mirrors [getOrCreateDeviceToken]'s retry-poll shape: AppDelegate's
  /// `pushRegistry(_:didUpdate:for:)` callback can arrive a moment after
  /// `PKPushRegistry.desiredPushTypes` is set, so poll briefly before giving
  /// up. iOS only — VoIP pushes/CallKit are not wired up for Android in this
  /// phase.
  Future<String?> getOrCreateVoipToken() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return null;
    }

    for (var attempt = 0; attempt < 6; attempt++) {
      try {
        final voipToken = await _channel.invokeMethod<String>('getPushTokenVoip');
        if (voipToken != null && voipToken.trim().isNotEmpty) {
          final trimmed = voipToken.trim();
          await _storage.write(key: _voipTokenKey, value: trimmed);
          return trimmed;
        }
      } catch (_) {}
      if (attempt < 5) await Future.delayed(const Duration(seconds: 1));
    }

    final existing = await _storage.read(key: _voipTokenKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    return null;
  }

  Future<void> syncTokenWithServer({
    required String baseUrl,
    required String accessToken,
    String? token,
    String tokenKind = 'default',
  }) async {
    final resolvedToken = token?.trim();
    final effectiveToken = resolvedToken != null && resolvedToken.isNotEmpty
        ? resolvedToken
        : await getOrCreateDeviceToken();
    if (effectiveToken == null || effectiveToken.isEmpty) {
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
          body: jsonEncode({
            'token': effectiveToken,
            'platform': _platformName(),
            'token_kind': tokenKind,
          }),
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Push token sync failed (${response.statusCode}).');
    }
  }

  /// Syncs the PushKit VoIP token to the server, tagged `token_kind: 'voip'`
  /// so it's kept distinct from the default APNs token.
  Future<void> syncVoipTokenWithServer({
    required String baseUrl,
    required String accessToken,
  }) async {
    final voipToken = await getOrCreateVoipToken();
    if (voipToken == null || voipToken.isEmpty) {
      return;
    }
    await syncTokenWithServer(
      baseUrl: baseUrl,
      accessToken: accessToken,
      token: voipToken,
      tokenKind: 'voip',
    );
  }

  /// Returns call metadata stored when the user tapped an incoming-call push
  /// notification while the app was backgrounded (iOS only). Clears the stored
  /// value after reading so it fires only once per tap.
  Future<Map<String, dynamic>?> getPendingCallNotification() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return null;
    try {
      final result = await _channel.invokeMethod<Map>('getPendingCallNotification');
      if (result == null) return null;
      return result.cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }

  Future<void> showIncomingMessageNotification({String? avatarBase64}) async {
    if (kIsWeb) {
      return;
    }

    final normalizedAvatar = avatarBase64?.trim();

    try {
      await _channel.invokeMethod<void>('showLocalNotification', {
        'title': 'Sync',
        'body': 'New message',
        'avatarBase64': normalizedAvatar == null || normalizedAvatar.isEmpty
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
