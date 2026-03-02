import 'dart:async';
import 'dart:convert';
import 'dart:math';

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
    required String accessToken,
    required String currentUserId,
  }) async {
    _closedByUser = false;
    _attempt = 0;
    await _open(
      baseUrl: baseUrl,
      accessToken: accessToken,
      currentUserId: currentUserId,
      initial: true,
    );
  }

  Future<void> disconnect() async {
    _closedByUser = true;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    await _channelSubscription?.cancel();
    await _channel?.sink.close();
    _channel = null;
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
    required String accessToken,
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
            accessToken: accessToken,
            currentUserId: currentUserId,
          );
        },
        onDone: () {
          _scheduleReconnect(
            baseUrl: baseUrl,
            accessToken: accessToken,
            currentUserId: currentUserId,
          );
        },
        cancelOnError: true,
      );
    } catch (error) {
      _events.add(RealtimeEvent.error(error.toString()));
      _scheduleReconnect(
        baseUrl: baseUrl,
        accessToken: accessToken,
        currentUserId: currentUserId,
      );
    }
  }

  void _scheduleReconnect({
    required String baseUrl,
    required String accessToken,
    required String currentUserId,
  }) {
    if (_closedByUser) {
      return;
    }

    _attempt += 1;
    final jitter = Random.secure().nextInt(400);
    final delayMs = min(1000 * _attempt, 8000) + jitter;

    _pingTimer?.cancel();
    _channelSubscription?.cancel();
    _channel = null;

    _events.add(RealtimeEvent.connection(RealtimeConnectionStatus.reconnecting));

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(milliseconds: delayMs), () {
      _open(
        baseUrl: baseUrl,
        accessToken: accessToken,
        currentUserId: currentUserId,
        initial: false,
      );
    });
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

  Uri _wsUri(String baseUrl, String accessToken) {
    final httpUri = Uri.parse(baseUrl.trim());
    final scheme = httpUri.scheme == 'https' ? 'wss' : 'ws';
    final wsPath = httpUri.path.endsWith('/')
        ? '${httpUri.path}ws'
        : '${httpUri.path}/ws';
    return Uri(
      scheme: scheme,
      host: httpUri.host,
      port: httpUri.hasPort ? httpUri.port : null,
      path: wsPath.replaceAll('//', '/'),
      queryParameters: {'token': accessToken},
    );
  }
}
