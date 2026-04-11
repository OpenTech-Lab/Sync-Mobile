import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/backup_crypto_service.dart';

void main() {
  final service = BackupCryptoService();

  test('encrypt/decrypt roundtrip preserves cleartext bytes', () async {
    final clear = utf8.encode('{"messages":[{"content":"secret"}]}');
    final key = SecretKey(List<int>.filled(32, 7));
    final nonce = List<int>.filled(12, 9);

    final payload = await service.encryptToJson(
      clearBytes: clear,
      secretKey: key,
      nonce: nonce,
    );

    final decrypted = await service.decryptFromJson(
      payload: payload,
      secretKey: key,
    );

    expect(utf8.decode(decrypted), utf8.decode(clear));
  });

  test('encrypted payload does not include plaintext message token', () async {
    const cleartext = '{"content":"highly-sensitive-text"}';
    final key = SecretKey(List<int>.filled(32, 4));
    final nonce = List<int>.filled(12, 1);

    final payload = await service.encryptToJson(
      clearBytes: utf8.encode(cleartext),
      secretKey: key,
      nonce: nonce,
    );

    expect(payload.contains('highly-sensitive-text'), isFalse);
  });
}
