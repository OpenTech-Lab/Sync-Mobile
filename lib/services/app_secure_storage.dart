import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSecureStorage {
  const AppSecureStorage([this._storage = const FlutterSecureStorage()]);

  static const _fallbackPrefix = 'secure_storage_fallback.';
  static bool _hasLoggedLinuxFallback = false;
  static bool _forceLinuxFallback = false;

  final FlutterSecureStorage _storage;

  Future<String?> read({required String key}) async {
    if (_forceLinuxFallback) {
      return _readFallback(key);
    }

    try {
      final value = await _storage.read(key: key);
      if (value != null) {
        return value;
      }
    } catch (error, stackTrace) {
      if (!_shouldFallback(error)) {
        rethrow;
      }
      _logLinuxFallback(error, stackTrace);
      return _readFallback(key);
    }

    return _readFallback(key);
  }

  Future<void> write({required String key, required String? value}) async {
    if (value == null) {
      await delete(key: key);
      return;
    }

    if (_forceLinuxFallback) {
      await _writeFallback(key, value);
      return;
    }

    try {
      await _storage.write(key: key, value: value);
      await _deleteFallback(key);
      return;
    } catch (error, stackTrace) {
      if (!_shouldFallback(error)) {
        rethrow;
      }
      _logLinuxFallback(error, stackTrace);
    }

    await _writeFallback(key, value);
  }

  Future<void> delete({required String key}) async {
    if (_forceLinuxFallback) {
      await _deleteFallback(key);
      return;
    }

    try {
      await _storage.delete(key: key);
    } catch (error, stackTrace) {
      if (!_shouldFallback(error)) {
        rethrow;
      }
      _logLinuxFallback(error, stackTrace);
    }

    await _deleteFallback(key);
  }

  bool _shouldFallback(Object error) {
    return !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.linux &&
        (error is PlatformException ||
            error is MissingPluginException ||
            error.toString().contains('libsecret_error'));
  }

  Future<String?> _readFallback(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_fallbackKey(key));
  }

  Future<void> _writeFallback(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fallbackKey(key), value);
  }

  Future<void> _deleteFallback(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_fallbackKey(key));
  }

  String _fallbackKey(String key) => '$_fallbackPrefix$key';

  void _logLinuxFallback(Object error, StackTrace stackTrace) {
    _forceLinuxFallback = true;
    if (_hasLoggedLinuxFallback) {
      return;
    }
    _hasLoggedLinuxFallback = true;
    debugPrint(
      'AppSecureStorage: libsecret unavailable on Linux; falling back to SharedPreferences.',
    );
    debugPrint('AppSecureStorage fallback cause: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}
