import 'dart:convert';

import 'package:http/http.dart' as http;

import 'dev_http_client.dart';
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
  RemoteChatService([http.Client? httpClient])
    : _httpClient = createDevHttpClient(httpClient);

  final http.Client _httpClient;

  Future<List<LocalChatMessage>> getConversation({
    required String baseUrl,
    required String accessToken,
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
    return json
        .map(
          (raw) => _fromRemoteJson(
            raw as Map<String, dynamic>,
            conversationId: partnerId,
          ),
        )
        .toList(growable: false);
  }

  Future<LocalChatMessage> sendMessage({
    required String baseUrl,
    required String accessToken,
    required String partnerId,
    required String body,
    String? recipientServerUrl,
  }) async {
    final normalized = _normalizeBaseUrl(baseUrl);
    final uri = Uri.parse('$normalized/api/messages');

    final normalizedServerUrl = recipientServerUrl?.trim();
    final response = await _httpClient
        .post(
          uri,
          headers: _authHeaders(accessToken),
          body: jsonEncode({
            'recipient_id': partnerId,
            if (normalizedServerUrl != null && normalizedServerUrl.isNotEmpty)
              'recipient_server_url': normalizedServerUrl,
            'content': body,
          }),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 201) {
      throw StateError('Failed to send message (${response.statusCode}).');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return _fromRemoteJson(json, conversationId: partnerId);
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

  LocalChatMessage _fromRemoteJson(
    Map<String, dynamic> json, {
    required String conversationId,
  }) {
    return LocalChatMessage(
      id: json['id'] as String,
      conversationId: conversationId,
      senderId: json['sender_id'] as String,
      body: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
    );
  }
}
