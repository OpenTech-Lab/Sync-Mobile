import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

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
      final channel = WebSocketChannel.connect(wsUri);
      _channel = channel;
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
    if (type != 'new_message') {
      return null;
    }

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

  @visibleForTesting
  Uri buildWebSocketUri({
    required String baseUrl,
    required String accessToken,
  }) {
    return _wsUri(baseUrl, accessToken);
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
