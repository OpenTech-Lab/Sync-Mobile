import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/chat_room.dart';
import 'dev_http_client.dart';
import 'message_e2ee_service.dart';
import '../models/local_chat_message.dart';
import '../models/user_profile.dart';

class RemoteChatApiException implements Exception {
  const RemoteChatApiException({
    required this.message,
    required this.statusCode,
    this.code,
    this.guild,
    this.retryAfterSeconds,
    this.allowedAttachmentTypes = const <String>[],
  });

  final String message;
  final int statusCode;
  final String? code;
  final UserGuildSnapshot? guild;
  final int? retryAfterSeconds;
  final List<String> allowedAttachmentTypes;

  factory RemoteChatApiException.fromResponse(
    http.Response response, {
    required String fallbackMessage,
  }) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return RemoteChatApiException(
          message:
              (decoded['error'] as String?) ??
              '$fallbackMessage (${response.statusCode}).',
          statusCode: response.statusCode,
          code: decoded['code'] as String?,
          guild: decoded['guild'] is Map<String, dynamic>
              ? UserGuildSnapshot.fromJson(
                  decoded['guild'] as Map<String, dynamic>,
                )
              : null,
          retryAfterSeconds: _parseOptionalInt(decoded['retry_after_seconds']),
          allowedAttachmentTypes:
              (decoded['allowed_mime_types'] as List<dynamic>? ?? const [])
                  .whereType<String>()
                  .toList(growable: false),
        );
      }
    } catch (_) {}

    return RemoteChatApiException(
      message: '$fallbackMessage (${response.statusCode}).',
      statusCode: response.statusCode,
    );
  }

  static int? _parseOptionalInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return null;
  }

  @override
  String toString() => message;
}

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

  Future<List<ChatRoom>> listRooms({
    required String baseUrl,
    required String accessToken,
  }) async {
    final normalized = _normalizeBaseUrl(baseUrl);
    final uri = Uri.parse('$normalized/api/rooms');

    final response = await _httpClient
        .get(uri, headers: _authHeaders(accessToken))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw StateError('Failed to load rooms (${response.statusCode}).');
    }

    final json = jsonDecode(response.body) as List<dynamic>;
    return json
        .map((raw) => ChatRoom.fromJson(raw as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<ChatRoom> createRoom({
    required String baseUrl,
    required String accessToken,
    required String name,
    required List<String> memberIds,
  }) async {
    final normalized = _normalizeBaseUrl(baseUrl);
    final uri = Uri.parse('$normalized/api/rooms');

    final response = await _httpClient
        .post(
          uri,
          headers: _authHeaders(accessToken),
          body: jsonEncode({'name': name.trim(), 'member_ids': memberIds}),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 201) {
      throw RemoteChatApiException.fromResponse(
        response,
        fallbackMessage: 'Failed to create room',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return ChatRoom.fromJson(json);
  }

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

  Future<List<LocalChatMessage>> getRoomMessages({
    required String baseUrl,
    required String accessToken,
    required String roomId,
    String? before,
    int limit = 50,
  }) async {
    final normalized = _normalizeBaseUrl(baseUrl);
    final uri = Uri.parse('$normalized/api/rooms/$roomId/messages').replace(
      queryParameters: {
        if (before != null && before.isNotEmpty) 'before': before,
        'limit': '$limit',
      },
    );

    final response = await _httpClient
        .get(uri, headers: _authHeaders(accessToken))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw StateError(
        'Failed to load room messages (${response.statusCode}).',
      );
    }

    final json = jsonDecode(response.body) as List<dynamic>;
    final conversationId = roomConversationId(roomId);
    return json
        .map(
          (raw) => _fromRoomMessageJson(
            raw as Map<String, dynamic>,
            conversationId: conversationId,
          ),
        )
        .toList(growable: false);
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
      throw RemoteChatApiException.fromResponse(
        response,
        fallbackMessage: 'Failed to send message',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return _fromRemoteJson(
      json,
      conversationId: partnerId,
      currentUserId: currentUserId,
    );
  }

  Future<LocalChatMessage> sendRoomMessage({
    required String baseUrl,
    required String accessToken,
    required String roomId,
    required String body,
  }) async {
    final normalized = _normalizeBaseUrl(baseUrl);
    final uri = Uri.parse('$normalized/api/rooms/$roomId/messages');

    final response = await _httpClient
        .post(
          uri,
          headers: _authHeaders(accessToken),
          body: jsonEncode({'content': body}),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 201) {
      throw RemoteChatApiException.fromResponse(
        response,
        fallbackMessage: 'Failed to send room message',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return _fromRoomMessageJson(
      json,
      conversationId: roomConversationId(roomId),
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

  Future<RoomDetail> getRoom({
    required String baseUrl,
    required String accessToken,
    required String roomId,
  }) async {
    final normalized = _normalizeBaseUrl(baseUrl);
    final uri = Uri.parse('$normalized/api/rooms/$roomId');

    final response = await _httpClient
        .get(uri, headers: _authHeaders(accessToken))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw RemoteChatApiException.fromResponse(
        response,
        fallbackMessage: 'Failed to load room detail',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return RoomDetail.fromJson(json);
  }

  Future<RoomDetail> renameRoom({
    required String baseUrl,
    required String accessToken,
    required String roomId,
    required String name,
  }) async {
    final normalized = _normalizeBaseUrl(baseUrl);
    final uri = Uri.parse('$normalized/api/rooms/$roomId');

    final response = await _httpClient
        .patch(
          uri,
          headers: _authHeaders(accessToken),
          body: jsonEncode({'name': name.trim()}),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw RemoteChatApiException.fromResponse(
        response,
        fallbackMessage: 'Failed to rename room',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return RoomDetail.fromJson(json);
  }

  Future<RoomDetail> addRoomMembers({
    required String baseUrl,
    required String accessToken,
    required String roomId,
    required List<String> memberIds,
  }) async {
    final normalized = _normalizeBaseUrl(baseUrl);
    final uri = Uri.parse('$normalized/api/rooms/$roomId/members');

    final response = await _httpClient
        .post(
          uri,
          headers: _authHeaders(accessToken),
          body: jsonEncode({'member_ids': memberIds}),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw RemoteChatApiException.fromResponse(
        response,
        fallbackMessage: 'Failed to add room members',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return RoomDetail.fromJson(json);
  }

  Future<RoomDetail> removeRoomMember({
    required String baseUrl,
    required String accessToken,
    required String roomId,
    required String memberId,
  }) async {
    final normalized = _normalizeBaseUrl(baseUrl);
    final uri = Uri.parse('$normalized/api/rooms/$roomId/members/$memberId');

    final response = await _httpClient
        .delete(uri, headers: _authHeaders(accessToken))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw RemoteChatApiException.fromResponse(
        response,
        fallbackMessage: 'Failed to remove room member',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return RoomDetail.fromJson(json);
  }

  Future<void> leaveRoom({
    required String baseUrl,
    required String accessToken,
    required String roomId,
  }) async {
    final normalized = _normalizeBaseUrl(baseUrl);
    final uri = Uri.parse('$normalized/api/rooms/$roomId/leave');

    final response = await _httpClient
        .post(uri, headers: _authHeaders(accessToken))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 204) {
      throw RemoteChatApiException.fromResponse(
        response,
        fallbackMessage: 'Failed to leave room',
      );
    }
  }

  Future<void> deleteRoom({
    required String baseUrl,
    required String accessToken,
    required String roomId,
  }) async {
    final normalized = _normalizeBaseUrl(baseUrl);
    final uri = Uri.parse('$normalized/api/rooms/$roomId');

    final response = await _httpClient
        .delete(uri, headers: _authHeaders(accessToken))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 204) {
      throw RemoteChatApiException.fromResponse(
        response,
        fallbackMessage: 'Failed to delete room',
      );
    }
  }

  Future<int> markRoomRead({
    required String baseUrl,
    required String accessToken,
    required String roomId,
  }) async {
    final normalized = _normalizeBaseUrl(baseUrl);
    final uri = Uri.parse('$normalized/api/rooms/$roomId/read');

    final response = await _httpClient
        .post(uri, headers: _authHeaders(accessToken))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw StateError('Failed to mark room read (${response.statusCode}).');
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

  LocalChatMessage _fromRoomMessageJson(
    Map<String, dynamic> json, {
    required String conversationId,
  }) {
    return LocalChatMessage(
      id: json['id'] as String,
      conversationId: conversationId,
      senderId: json['sender_id'] as String,
      body: (json['content'] as String?)?.trim() ?? '',
      createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
    );
  }
}
