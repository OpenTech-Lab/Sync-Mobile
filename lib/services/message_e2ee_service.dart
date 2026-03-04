import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class MessageE2eeService {
  MessageE2eeService({
    FlutterSecureStorage? secureStorage,
    Cryptography? cryptography,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _cryptography = cryptography ?? Cryptography.instance,
       _cipher = AesGcm.with256bits(),
       // PBKDF2 is kept only for the one-time password-based seed derivation.
       _passwordKdf = Pbkdf2(
         macAlgorithm: Hmac.sha256(),
         iterations: 210000,
         bits: 256,
       ),
       // HKDF is used for per-message AES key derivation from the X25519
       // shared secret: single-pass, appropriate for strong key material,
       // and orders of magnitude faster than PBKDF2.
       _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  static const _seedKey = 'chat_e2ee_seed_v1';
  static const _metaKey = 'chat_e2ee_meta_v1';

  /// Algorithm tag written into every new envelope.
  static const _currentAlg = 'x25519_hkdf_aes_gcm_256';

  /// Legacy algorithm tag produced by older clients (PBKDF2-based).
  static const _legacyAlg = 'x25519_aes_gcm_256';

  final FlutterSecureStorage _secureStorage;
  final Cryptography _cryptography;
  final Cipher _cipher;
  final Pbkdf2 _passwordKdf;
  final Hkdf _hkdf;

  KeyExchangeAlgorithm get _x25519 => _cryptography.x25519();

  Future<String?> readStoredPublicKey() async {
    final seed = await _readSeed();
    if (seed == null) {
      return null;
    }
    final keyPair = await _keyPairFromSeed(seed);
    final publicKey = await keyPair.extractPublicKey();
    return base64Encode(publicKey.bytes);
  }

  Future<String> ensurePublicKeyBase64({
    required String serverUrl,
    required String email,
    String? password,
  }) async {
    final seed = await _ensureSeed(
      serverUrl: serverUrl,
      email: email,
      password: password,
    );
    final keyPair = await _keyPairFromSeed(seed);
    final publicKey = await keyPair.extractPublicKey();
    return base64Encode(publicKey.bytes);
  }

  Future<String> ensureDevicePublicKeyBase64() async {
    final seed = await _ensureSeed(
      serverUrl: 'device-local',
      email: 'device-local',
      password: null,
    );
    final keyPair = await _keyPairFromSeed(seed);
    final publicKey = await keyPair.extractPublicKey();
    return base64Encode(publicKey.bytes);
  }

  Future<String> encryptEnvelope({
    required String clearText,
    required String recipientPublicKeyBase64,
    required String senderPublicKeyBase64,
  }) async {
    final clearBytes = utf8.encode(clearText);

    final recipientPayload = await _encryptForPublicKey(
      clearBytes: clearBytes,
      recipientPublicKeyBase64: recipientPublicKeyBase64,
    );
    final senderPayload = await _encryptForPublicKey(
      clearBytes: clearBytes,
      recipientPublicKeyBase64: senderPublicKeyBase64,
    );

    return jsonEncode({
      'v': 1,
      'alg': _currentAlg,
      'recipient': recipientPayload,
      'sender': senderPayload,
    });
  }

  Future<String?> tryDecryptEnvelope({
    required String content,
    required bool sentByCurrentUser,
  }) async {
    final normalized = content.trim();
    if (!isEncryptedEnvelope(normalized)) {
      return normalized;
    }

    final seed = await _readSeed();
    if (seed == null) {
      return null;
    }

    final decoded = jsonDecode(normalized);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    // Detect algorithm so we can use the matching KDF for backward compat.
    final alg = decoded['alg'] as String? ?? _legacyAlg;

    final block = decoded[sentByCurrentUser ? 'sender' : 'recipient'];
    if (block is! Map<String, dynamic>) {
      return null;
    }

    final keyPair = await _keyPairFromSeed(seed);
    final localPrivate = await keyPair.extractPrivateKeyBytes();
    final localKeyPairData = SimpleKeyPairData(
      localPrivate,
      publicKey: await keyPair.extractPublicKey(),
      type: KeyPairType.x25519,
    );

    final ephemeralPublic = block['ephemeral_public_key'] as String?;
    final nonce = block['nonce'] as String?;
    final cipherText = block['cipher_text'] as String?;
    final mac = block['mac'] as String?;
    if (ephemeralPublic == null ||
        nonce == null ||
        cipherText == null ||
        mac == null) {
      return null;
    }

    try {
      final sharedSecret = await _x25519.sharedSecretKey(
        keyPair: localKeyPairData,
        remotePublicKey: SimplePublicKey(
          base64Decode(ephemeralPublic),
          type: KeyPairType.x25519,
        ),
      );
      final aesKey = await _deriveAesKey(sharedSecret, alg: alg);
      final plainBytes = await _cipher.decrypt(
        SecretBox(
          base64Decode(cipherText),
          nonce: base64Decode(nonce),
          mac: Mac(base64Decode(mac)),
        ),
        secretKey: aesKey,
      );
      return utf8.decode(plainBytes);
    } catch (_) {
      return null;
    }
  }

  bool isEncryptedEnvelope(String content) {
    if (!content.startsWith('{') || !content.endsWith('}')) {
      return false;
    }
    try {
      final decoded = jsonDecode(content);
      return decoded is Map<String, dynamic> &&
          decoded['v'] == 1 &&
          decoded['recipient'] is Map<String, dynamic> &&
          decoded['sender'] is Map<String, dynamic>;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, String>> _encryptForPublicKey({
    required List<int> clearBytes,
    required String recipientPublicKeyBase64,
  }) async {
    final recipientPublicKey = SimplePublicKey(
      base64Decode(recipientPublicKeyBase64),
      type: KeyPairType.x25519,
    );
    final ephemeral = await _x25519.newKeyPair();
    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: ephemeral,
      remotePublicKey: recipientPublicKey,
    );
    final aesKey = await _deriveAesKey(sharedSecret);
    final nonce = _randomBytes(12);
    final secretBox = await _cipher.encrypt(
      clearBytes,
      secretKey: aesKey,
      nonce: nonce,
    );
    final ephemeralPublic =
        await ephemeral.extractPublicKey() as SimplePublicKey;
    return {
      'ephemeral_public_key': base64Encode(ephemeralPublic.bytes),
      'nonce': base64Encode(secretBox.nonce),
      'cipher_text': base64Encode(secretBox.cipherText),
      'mac': base64Encode(secretBox.mac.bytes),
    };
  }

  /// Derives the per-message AES-256 key from an X25519 shared secret.
  ///
  /// New messages use HKDF (fast, single-pass, appropriate for strong key
  /// material). Legacy messages fall back to PBKDF2 so they can still be
  /// decrypted.
  Future<SecretKey> _deriveAesKey(
    SecretKey sharedSecret, {
    String alg = _currentAlg,
  }) async {
    if (alg == _legacyAlg) {
      // Backward compat: old clients encrypted with PBKDF2.
      return _passwordKdf.deriveKey(
        secretKey: sharedSecret,
        nonce: utf8.encode('sync-chat-e2ee-v1'),
      );
    }
    // Fast path: HKDF — appropriate when key material is already strong.
    return _hkdf.deriveKey(
      secretKey: sharedSecret,
      nonce: utf8.encode('sync-chat-e2ee-v1'),
    );
  }

  Future<List<int>> _ensureSeed({
    required String serverUrl,
    required String email,
    String? password,
  }) async {
    final existing = await _readSeed();
    if (existing != null) {
      return existing;
    }
    final normalizedPassword = password?.trim();
    if (normalizedPassword == null || normalizedPassword.isEmpty) {
      final randomSeed = _randomBytes(32);
      await _secureStorage.write(
        key: _seedKey,
        value: base64Encode(randomSeed),
      );
      await _secureStorage.write(
        key: _metaKey,
        value: jsonEncode({
          'server_url': serverUrl.trim(),
          'email': email.trim().toLowerCase(),
          'mode': 'device_random_seed',
        }),
      );
      return randomSeed;
    }

    final seed = await _deriveSeed(
      serverUrl: serverUrl,
      email: email,
      password: normalizedPassword,
    );
    await _secureStorage.write(key: _seedKey, value: base64Encode(seed));
    await _secureStorage.write(
      key: _metaKey,
      value: jsonEncode({
        'server_url': serverUrl.trim(),
        'email': email.trim().toLowerCase(),
      }),
    );
    return seed;
  }

  Future<List<int>?> _readSeed() async {
    final raw = await _secureStorage.read(key: _seedKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    return base64Decode(raw);
  }

  Future<List<int>> _deriveSeed({
    required String serverUrl,
    required String email,
    required String password,
  }) async {
    final salt = utf8.encode(
      'sync-e2ee:${serverUrl.trim().toLowerCase()}:${email.trim().toLowerCase()}',
    );
    final secret = SecretKey(utf8.encode(password));
    // PBKDF2 is appropriate here: we are stretching a user-supplied password.
    final derived = await _passwordKdf.deriveKey(secretKey: secret, nonce: salt);
    return derived.extractBytes();
  }

  Future<SimpleKeyPair> _keyPairFromSeed(List<int> seed) async {
    return await _x25519.newKeyPairFromSeed(seed) as SimpleKeyPair;
  }

  List<int> _randomBytes(int size) {
    final random = Random.secure();
    return List<int>.generate(
      size,
      (_) => random.nextInt(256),
      growable: false,
    );
  }
}
