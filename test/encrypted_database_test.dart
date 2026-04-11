import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/encrypted_database.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class _FakeDatabaseException extends DatabaseException {
  _FakeDatabaseException(super.message);

  @override
  int? getResultCode() => null;

  @override
  Object? get result => null;
}

void main() {
  group('selectStoredEncryptionKey', () {
    test('prefers scoped key over stale legacy key for existing scoped db', () {
      final key = selectStoredEncryptionKey(
        scopedFileExists: true,
        scopedKey: 'scoped-key',
        legacyKey: 'legacy-key',
      );

      expect(key, 'scoped-key');
    });

    test('uses legacy key when scoped db exists but scoped key is missing', () {
      final key = selectStoredEncryptionKey(
        scopedFileExists: true,
        scopedKey: null,
        legacyKey: 'legacy-key',
      );

      expect(key, 'legacy-key');
    });

    test('returns null when no stored key can unlock the db', () {
      final key = selectStoredEncryptionKey(
        scopedFileExists: false,
        scopedKey: null,
        legacyKey: 'legacy-key',
      );

      expect(key, isNull);
    });
  });

  group('isRecoverableDatabaseOpenError', () {
    test('matches SQLCipher not-a-database failures', () {
      expect(
        isRecoverableDatabaseOpenError(
          Exception('SQLiteNotADatabaseException: file is not a database'),
        ),
        isTrue,
      );
    });

    test('matches SQLCipher hmac failures', () {
      expect(
        isRecoverableDatabaseOpenError(
          Exception('sqlcipher_page_cipher: hmac check failed for pgno=1'),
        ),
        isTrue,
      );
    });

    test('matches wrapped sqflite open_failed exceptions', () {
      expect(
        isRecoverableDatabaseOpenError(
          _FakeDatabaseException(
            'open_failed /data/user/0/app_flutter/sync_local_chat_192.168.11.9.db',
          ),
        ),
        isTrue,
      );
    });
  });
}
