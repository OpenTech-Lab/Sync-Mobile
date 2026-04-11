import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;

import '../models/local_chat_message.dart';
import 'backup_crypto_service.dart';
import 'dev_http_client.dart';

class RemoteBackupService {
  RemoteBackupService([http.Client? httpClient])
    : _httpClient = createDevHttpClient(httpClient);

  final http.Client _httpClient;
  final _crypto = BackupCryptoService();

  Future<void> uploadBackup({
    required String baseUrl,
    required String accessToken,
    required List<LocalChatMessage> messages,
    required List<int> keyBytes,
  }) async {
    final payload = jsonEncode({
      'version': 1,
      'messages': messages.map((message) => message.toMap()).toList(),
    });
    final nonce = List<int>.generate(12, (_) => Random.secure().nextInt(256));
    final encryptedBlob = await _crypto.encryptToJson(
      clearBytes: utf8.encode(payload),
      secretKey: SecretKey(keyBytes),
      nonce: nonce,
    );

    final normalized = _normalizeBaseUrl(baseUrl);
    final uri = Uri.parse('$normalized/api/backup');
    final response = await _httpClient
        .put(
          uri,
          headers: _authHeaders(accessToken),
          body: jsonEncode({'encrypted_blob': encryptedBlob}),
        )
        .timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) {
      throw StateError('Failed to upload backup (${response.statusCode}).');
    }
  }

  Future<List<LocalChatMessage>> restoreBackup({
    required String baseUrl,
    required String accessToken,
    required List<int> keyBytes,
  }) async {
    final normalized = _normalizeBaseUrl(baseUrl);
    final uri = Uri.parse('$normalized/api/backup');
    final response = await _httpClient
        .get(uri, headers: _authHeaders(accessToken))
        .timeout(const Duration(seconds: 12));

    if (response.statusCode == 404) {
      return const [];
    }

    if (response.statusCode != 200) {
      throw StateError('Failed to fetch backup (${response.statusCode}).');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final encryptedBlob = decoded['encrypted_blob'] as String?;
    if (encryptedBlob == null || encryptedBlob.isEmpty) {
      return const [];
    }

    final clearBytes = await _crypto.decryptFromJson(
      payload: encryptedBlob,
      secretKey: SecretKey(keyBytes),
    );
    final payload = jsonDecode(utf8.decode(clearBytes)) as Map<String, dynamic>;
    final messages = payload['messages'] as List<dynamic>? ?? const [];
    return messages
        .map(
          (item) => LocalChatMessage.fromMap(Map<String, Object?>.from(item)),
        )
        .toList(growable: false);
  }

  Future<void> deleteBackup({
    required String baseUrl,
    required String accessToken,
  }) async {
    final normalized = _normalizeBaseUrl(baseUrl);
    final uri = Uri.parse('$normalized/api/backup');
    final response = await _httpClient
        .delete(uri, headers: _authHeaders(accessToken))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 204) {
      throw StateError('Failed to delete backup (${response.statusCode}).');
    }
  }

  String _normalizeBaseUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  Map<String, String> _authHeaders(String accessToken) {
    return {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    };
  }
}
