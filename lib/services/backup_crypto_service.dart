import 'dart:convert';

import 'package:cryptography/cryptography.dart';

class BackupCryptoService {
  BackupCryptoService([Cipher? cipher])
    : _cipher = cipher ?? AesGcm.with256bits();

  final Cipher _cipher;

  Future<String> encryptToJson({
    required List<int> clearBytes,
    required SecretKey secretKey,
    required List<int> nonce,
  }) async {
    final secretBox = await _cipher.encrypt(
      clearBytes,
      secretKey: secretKey,
      nonce: nonce,
    );

    return jsonEncode({
      'nonce': base64Encode(secretBox.nonce),
      'cipherText': base64Encode(secretBox.cipherText),
      'mac': base64Encode(secretBox.mac.bytes),
    });
  }

  Future<List<int>> decryptFromJson({
    required String payload,
    required SecretKey secretKey,
  }) async {
    final encoded = jsonDecode(payload) as Map<String, dynamic>;
    final nonce = base64Decode(encoded['nonce'] as String);
    final cipherText = base64Decode(encoded['cipherText'] as String);
    final macBytes = base64Decode(encoded['mac'] as String);

    final box = SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes));
    return _cipher.decrypt(box, secretKey: secretKey);
  }
}
