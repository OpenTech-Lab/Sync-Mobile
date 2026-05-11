import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'dev_web_socket_channel.dart';
import '../models/chat_room.dart';
import '../models/local_chat_message.dart';
import '../models/realtime_event.dart';

class RealtimeSyncService {
  RealtimeSyncService();

  final _events = StreamController<RealtimeEvent>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription? _channelSubscription;
  Timer? _pingTimer;
  Timer? _reconnectTimer;

  bool _closedByUser = false;
  int _attempt = 0;

  Stream<RealtimeEvent> get events => _events.stream;

  Future<void> connect({
    required String baseUrl,
    required Future<String?> Function() accessTokenProvider,
    required String currentUserId,
  }) async {
    _closedByUser = false;
    _attempt = 0;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _closeChannel();
    await _open(
      baseUrl: baseUrl,
      accessTokenProvider: accessTokenProvider,
      currentUserId: currentUserId,
      initial: true,
    );
  }

  Future<void> disconnect() async {
    _closedByUser = true;
    _reconnectTimer?.cancel();
    await _closeChannel();
    _events.add(
      RealtimeEvent.connection(RealtimeConnectionStatus.disconnected),
    );
  }

  void sendTyping({required String partnerId, required bool isTyping}) {
    final channel = _channel;
    if (channel == null) {
      return;
    }
    try {
      channel.sink.add(
        jsonEncode({
          'type': 'typing',
          'partner_id': partnerId,
          'is_typing': isTyping,
        }),
      );
    } catch (_) {}
  }

  void sendCallSignal(Map<String, dynamic> payload) {
    final channel = _channel;
    if (channel == null) return;
    try {
      channel.sink.add(jsonEncode(payload));
    } catch (_) {}
  }

  Future<void> dispose() async {
    await disconnect();
    await _events.close();
  }

  Future<void> _open({
    required String baseUrl,
    required Future<String?> Function() accessTokenProvider,
    required String currentUserId,
    required bool initial,
  }) async {
    _events.add(
      RealtimeEvent.connection(
        initial
            ? RealtimeConnectionStatus.connecting
            : RealtimeConnectionStatus.reconnecting,
      ),
    );

    try {
      final accessToken = await accessTokenProvider();
      if (accessToken == null || accessToken.trim().isEmpty) {
        _events.add(RealtimeEvent.error('Missing access token for realtime.'));
        _scheduleReconnect(
          baseUrl: baseUrl,
          accessTokenProvider: accessTokenProvider,
          currentUserId: currentUserId,
        );
        return;
      }
      final wsUri = _wsUri(baseUrl, accessToken);
      final channel = connectDevWebSocketChannel(wsUri);
      _channel = channel;
      await channel.ready;
      _events.add(RealtimeEvent.connection(RealtimeConnectionStatus.connected));

      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 20), (_) {
        try {
          channel.sink.add(jsonEncode({'type': 'ping'}));
        } catch (_) {}
      });

      _channelSubscription = channel.stream.listen(
        (payload) {
          final event = _tryParseRealtimeEvent(
            payload: payload,
            currentUserId: currentUserId,
          );
          if (event != null) {
            _events.add(event);
          }
        },
        onError: (error) {
          _events.add(RealtimeEvent.error(error.toString()));
          _scheduleReconnect(
            baseUrl: baseUrl,
            accessTokenProvider: accessTokenProvider,
            currentUserId: currentUserId,
          );
        },
        onDone: () {
          _scheduleReconnect(
            baseUrl: baseUrl,
            accessTokenProvider: accessTokenProvider,
            currentUserId: currentUserId,
          );
        },
        cancelOnError: true,
      );
    } catch (error) {
      _events.add(RealtimeEvent.error(error.toString()));
      _scheduleReconnect(
        baseUrl: baseUrl,
        accessTokenProvider: accessTokenProvider,
        currentUserId: currentUserId,
      );
    }
  }

  void _scheduleReconnect({
    required String baseUrl,
    required Future<String?> Function() accessTokenProvider,
    required String currentUserId,
  }) {
    if (_closedByUser) {
      return;
    }

    _attempt += 1;
    final jitter = Random.secure().nextInt(400);
    final delayMs = min(1000 * _attempt, 8000) + jitter;

    unawaited(_closeChannel());

    _events.add(
      RealtimeEvent.connection(RealtimeConnectionStatus.reconnecting),
    );

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(milliseconds: delayMs), () {
      _open(
        baseUrl: baseUrl,
        accessTokenProvider: accessTokenProvider,
        currentUserId: currentUserId,
        initial: false,
      );
    });
  }

  Future<void> _closeChannel() async {
    _pingTimer?.cancel();
    await _channelSubscription?.cancel();
    await _channel?.sink.close();
    _channel = null;
  }

  RealtimeEvent? _tryParseRealtimeEvent({
    required dynamic payload,
    required String currentUserId,
  }) {
    if (payload is! String) {
      return null;
    }

    final decoded = jsonDecode(payload);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    final type = decoded['type'];
    if (type == 'new_message') {
      final messageJson = decoded['message'];
      if (messageJson is! Map<String, dynamic>) {
        return null;
      }

      final senderId = messageJson['sender_id'] as String?;
      final recipientId = messageJson['recipient_id'] as String?;
      if (senderId == null || recipientId == null) {
        return null;
      }

      final partnerId = senderId == currentUserId ? recipientId : senderId;

      final message = LocalChatMessage(
        id: messageJson['id'] as String,
        conversationId: partnerId,
        senderId: senderId,
        body: messageJson['content'] as String,
        createdAt: DateTime.parse(messageJson['created_at'] as String).toUtc(),
      );
      return RealtimeEvent.message(message);
    }

    if (type == 'new_room_message') {
      final roomId = decoded['room_id'] as String?;
      final messageJson = decoded['message'];
      if (roomId == null || messageJson is! Map<String, dynamic>) {
        return null;
      }
      final senderId = messageJson['sender_id'] as String?;
      if (senderId == null) {
        return null;
      }

      final message = LocalChatMessage(
        id: messageJson['id'] as String,
        conversationId: roomConversationId(roomId),
        senderId: senderId,
        body: (messageJson['content'] as String?) ?? '',
        createdAt: DateTime.parse(messageJson['created_at'] as String).toUtc(),
      );
      return RealtimeEvent.message(message);
    }

    if (type == 'typing') {
      final senderId = decoded['sender_id'] as String?;
      final recipientId = decoded['recipient_id'] as String?;
      final isTyping = decoded['is_typing'] as bool?;
      if (senderId == null || recipientId == null || isTyping == null) {
        return null;
      }
      final partnerId = senderId == currentUserId ? recipientId : senderId;
      return RealtimeEvent.typing(partnerId: partnerId, isTyping: isTyping);
    }

    if (type == 'room_membership_changed') {
      final roomId = decoded['room_id'] as String?;
      if (roomId == null || roomId.trim().isEmpty) {
        return null;
      }
      return RealtimeEvent.roomMembershipChanged(roomId: roomId);
    }

    if (type == 'call_created') {
      final callId = decoded['call_id'] as String?;
      final calleeId = decoded['callee_id'] as String?;
      if (callId == null || calleeId == null) {
        return null;
      }
      return RealtimeEvent.callCreated(callId: callId, calleeId: calleeId);
    }

    if (type == 'incoming_call') {
      final callId = decoded['call_id'] as String?;
      final callerId = decoded['caller_id'] as String?;
      final callType = decoded['call_type'] as String?;
      final sdpOffer = decoded['sdp_offer'] as String?;
      if (callId == null ||
          callerId == null ||
          callType == null ||
          sdpOffer == null) {
        return null;
      }
      return RealtimeEvent.incomingCall(
        callId: callId,
        callerId: callerId,
        callType: callType,
        sdpOffer: sdpOffer,
      );
    }

    if (type == 'call_answered') {
      final callId = decoded['call_id'] as String?;
      final calleeId = decoded['callee_id'] as String?;
      final sdpAnswer = decoded['sdp_answer'] as String?;
      if (callId == null || calleeId == null || sdpAnswer == null) {
        return null;
      }
      return RealtimeEvent.callAnswered(
        callId: callId,
        calleeId: calleeId,
        sdpAnswer: sdpAnswer,
      );
    }

    if (type == 'call_rejected') {
      final callId = decoded['call_id'] as String?;
      if (callId == null) return null;
      return RealtimeEvent.callRejected(callId: callId);
    }

    if (type == 'call_hangup') {
      final callId = decoded['call_id'] as String?;
      if (callId == null) return null;
      return RealtimeEvent.callHangup(callId: callId);
    }

    if (type == 'ice_candidate') {
      final callId = decoded['call_id'] as String?;
      final fromUserId = decoded['from_user_id'] as String?;
      final candidate = decoded['candidate'] as String?;
      if (callId == null || fromUserId == null || candidate == null) {
        return null;
      }
      return RealtimeEvent.iceCandidate(
        callId: callId,
        fromUserId: fromUserId,
        candidate: candidate,
        sdpMid: decoded['sdp_mid'] as String?,
        sdpMlineIndex: decoded['sdp_mline_index'] as int?,
      );
    }

    return null;
  }

  @visibleForTesting
  Uri buildWebSocketUri({
    required String baseUrl,
    required String accessToken,
  }) {
    return _wsUri(baseUrl, accessToken);
  }

  @visibleForTesting
  RealtimeEvent? tryParseRealtimeEventForTest({
    required dynamic payload,
    required String currentUserId,
  }) {
    return _tryParseRealtimeEvent(
      payload: payload,
      currentUserId: currentUserId,
    );
  }

  Uri _wsUri(String baseUrl, String accessToken) {
    final httpUri = Uri.parse(baseUrl.trim().replaceFirst(RegExp(r'#.*$'), ''));
    final scheme = httpUri.scheme == 'https' ? 'wss' : 'ws';
    final defaultPort = httpUri.scheme == 'https' ? 443 : 80;
    final port = (httpUri.hasPort && httpUri.port > 0)
        ? httpUri.port
        : defaultPort;
    final wsPath = httpUri.path.endsWith('/')
        ? '${httpUri.path}ws'
        : '${httpUri.path}/ws';
    final normalizedPath = wsPath.replaceAll('//', '/');
    final token = Uri.encodeQueryComponent(accessToken);
    return Uri(
      scheme: scheme,
      host: httpUri.host,
      port: port,
      path: normalizedPath,
      query: 'token=$token',
    );
  }
}
