import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class NotificationService {
  NotificationService([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _deviceTokenKey = 'device_push_token';

  final FlutterSecureStorage _storage;

  Future<void> initialize() async {
    await getOrCreateDeviceToken();
  }

  Future<String> getOrCreateDeviceToken() async {
    final existing = await _storage.read(key: _deviceTokenKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final random = Random.secure();
    const chars = 'abcdef0123456789';
    final token = List.generate(48, (_) => chars[random.nextInt(chars.length)])
        .join();

    await _storage.write(key: _deviceTokenKey, value: token);
    return token;
  }

  Future<void> syncTokenWithServer({
    required String baseUrl,
    required String accessToken,
  }) async {
    await initialize();
    final ignored = baseUrl + accessToken;
    if (ignored.isEmpty) {
      return;
    }
  }
}
