import 'dart:convert';

import 'package:http/http.dart' as http;

import 'dev_http_client.dart';
import 'message_e2ee_service.dart';
import '../models/local_chat_message.dart';

class ResolvedContact {
  const ResolvedContact({
    required this.partnerId,
    required this.recipientId,
    required this.recipientServerUrl,
    required this.displayHandle,
  });

  final String partnerId;
  final String recipientId;
  final String recipientServerUrl;
  final String displayHandle;

  factory ResolvedContact.fromJson(Map<String, dynamic> json) {
    return ResolvedContact(
      partnerId: json['partner_id'] as String,
      recipientId: json['recipient_id'] as String,
      recipientServerUrl: json['recipient_server_url'] as String,
      displayHandle: json['display_handle'] as String,
    );
  }
}

class RemoteChatService {
  RemoteChatService([http.Client? httpClient, MessageE2eeService? e2eeService])
    : _httpClient = createDevHttpClient(httpClient),
      _e2eeService = e2eeService ?? MessageE2eeService();

  final http.Client _httpClient;
  final MessageE2eeService _e2eeService;

  Future<List<LocalChatMessage>> getConversation({
    required String baseUrl,
    required String accessToken,
    required String currentUserId,
    required String partnerId,
    String? before,
    int limit = 30,
  }) async {
    final normalized = _normalizeBaseUrl(baseUrl);
    final uri = Uri.parse('$normalized/api/messages/$partnerId').replace(
      queryParameters: {
        if (before != null && before.isNotEmpty) 'before': before,
        'limit': '$limit',
      },
    );

    final response = await _httpClient
        .get(uri, headers: _authHeaders(accessToken))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw StateError('Failed to load conversation (${response.statusCode}).');
    }

    final json = jsonDecode(response.body) as List<dynamic>;
    final result = <LocalChatMessage>[];
    for (final raw in json) {
      result.add(
        await _fromRemoteJson(
          raw as Map<String, dynamic>,
          conversationId: partnerId,
          currentUserId: currentUserId,
        ),
      );
    }
    return result;
  }

  Future<LocalChatMessage> sendMessage({
    required String baseUrl,
    required String accessToken,
    required String currentUserId,
    required String senderPublicKey,
    required String recipientPublicKey,
    required String partnerId,
    required String body,
    String? recipientServerUrl,
  }) async {
    final normalized = _normalizeBaseUrl(baseUrl);
    final uri = Uri.parse('$normalized/api/messages');

    final normalizedServerUrl = recipientServerUrl?.trim();
    final encryptedContent = await _e2eeService.encryptEnvelope(
      clearText: body,
      recipientPublicKeyBase64: recipientPublicKey,
      senderPublicKeyBase64: senderPublicKey,
    );

    final response = await _httpClient
        .post(
          uri,
          headers: _authHeaders(accessToken),
          body: jsonEncode({
            'recipient_id': partnerId,
            if (normalizedServerUrl != null && normalizedServerUrl.isNotEmpty)
              'recipient_server_url': normalizedServerUrl,
            'content': encryptedContent,
          }),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 201) {
      throw StateError('Failed to send message (${response.statusCode}).');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return _fromRemoteJson(
      json,
      conversationId: partnerId,
      currentUserId: currentUserId,
    );
  }

  Future<ResolvedContact> resolveContact({
    required String baseUrl,
    required String accessToken,
    required String recipientId,
    required String recipientServerUrl,
  }) async {
    final normalized = _normalizeBaseUrl(baseUrl);
    final uri = Uri.parse('$normalized/api/messages/resolve-contact');

    final response = await _httpClient
        .post(
          uri,
          headers: _authHeaders(accessToken),
          body: jsonEncode({
            'recipient_id': recipientId.trim(),
            'recipient_server_url': recipientServerUrl.trim(),
          }),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw StateError('Failed to resolve contact (${response.statusCode}).');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return ResolvedContact.fromJson(json);
  }

  Future<int> markRead({
    required String baseUrl,
    required String accessToken,
    required String partnerId,
  }) async {
    final normalized = _normalizeBaseUrl(baseUrl);
    final uri = Uri.parse('$normalized/api/messages/$partnerId/read');

    final response = await _httpClient
        .post(uri, headers: _authHeaders(accessToken))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw StateError('Failed to mark read (${response.statusCode}).');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final count = json['count'];
    return count is int ? count : 0;
  }

  Future<Map<String, int>> getUnreadCounts({
    required String baseUrl,
    required String accessToken,
  }) async {
    final normalized = _normalizeBaseUrl(baseUrl);
    final uri = Uri.parse('$normalized/api/messages/unread-counts');

    final response = await _httpClient
        .get(uri, headers: _authHeaders(accessToken))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw StateError(
        'Failed to fetch unread counts (${response.statusCode}).',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded.map((key, value) => MapEntry(key, value is int ? value : 0));
  }

  Map<String, String> _authHeaders(String accessToken) {
    return {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    };
  }

  String _normalizeBaseUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  Future<LocalChatMessage> _fromRemoteJson(
    Map<String, dynamic> json, {
    required String conversationId,
    required String currentUserId,
  }) async {
    final senderId = json['sender_id'] as String;
    final sentByCurrentUser = senderId == currentUserId;
    final raw = (json['content'] as String?) ?? '';
    final decrypted = await _e2eeService.tryDecryptEnvelope(
      content: raw,
      sentByCurrentUser: sentByCurrentUser,
    );
    return LocalChatMessage(
      id: json['id'] as String,
      conversationId: conversationId,
      senderId: senderId,
      body: decrypted ?? '[Encrypted message: key unavailable on this device]',
      createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
    );
  }
}
