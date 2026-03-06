import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'server_scope.dart';

class SessionStorage {
  const SessionStorage([this._storage = const FlutterSecureStorage()]);

  static const _legacyAccessTokenKey = 'access_token';
  static const _legacyRefreshTokenKey = 'refresh_token';

  final FlutterSecureStorage _storage;

  String _accessTokenKey(String serverUrl) =>
      scopedStorageKey(_legacyAccessTokenKey, serverUrl);

  String _refreshTokenKey(String serverUrl) =>
      scopedStorageKey(_legacyRefreshTokenKey, serverUrl);

  Future<String?> readAccessToken(String serverUrl) {
    return _readScopedOrMigrate(
      scopedKey: _accessTokenKey(serverUrl),
      legacyKey: _legacyAccessTokenKey,
    );
  }

  Future<String?> readRefreshToken(String serverUrl) {
    return _readScopedOrMigrate(
      scopedKey: _refreshTokenKey(serverUrl),
      legacyKey: _legacyRefreshTokenKey,
    );
  }

  Future<void> writeTokens({
    required String serverUrl,
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _accessTokenKey(serverUrl), value: accessToken);
    await _storage.write(key: _refreshTokenKey(serverUrl), value: refreshToken);
    await _storage.delete(key: _legacyAccessTokenKey);
    await _storage.delete(key: _legacyRefreshTokenKey);
  }

  Future<void> clearTokens(String serverUrl) async {
    await _storage.delete(key: _accessTokenKey(serverUrl));
    await _storage.delete(key: _refreshTokenKey(serverUrl));
    await _storage.delete(key: _legacyAccessTokenKey);
    await _storage.delete(key: _legacyRefreshTokenKey);
  }

  Future<String?> _readScopedOrMigrate({
    required String scopedKey,
    required String legacyKey,
  }) async {
    final scoped = await _storage.read(key: scopedKey);
    if (scoped != null && scoped.isNotEmpty) {
      return scoped;
    }

    final legacy = await _storage.read(key: legacyKey);
    if (legacy == null || legacy.isEmpty) {
      return null;
    }

    await _storage.write(key: scopedKey, value: legacy);
    await _storage.delete(key: legacyKey);
    return legacy;
  }
}
