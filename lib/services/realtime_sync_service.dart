import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import 'dev_http_client.dart';
import 'dev_web_socket_channel.dart';
import '../models/chat_room.dart';
import '../models/local_chat_message.dart';
import '../models/realtime_event.dart';

/// The server has no `POST /auth/ws-ticket` (404/405): it predates tickets and
/// only understands the legacy `?token=` handshake. Any other ticket failure
/// is NOT this; see [RealtimeSyncService._resolveWebSocketUri].
class _WebSocketTicketUnsupported implements Exception {
  const _WebSocketTicketUnsupported();
}

class RealtimeSyncService {
  RealtimeSyncService([
    http.Client? httpClient,
    WebSocketChannel Function(Uri uri)? connectChannel,
  ]) : _httpClient = createDevHttpClient(httpClient),
       _connectChannel = connectChannel ?? connectDevWebSocketChannel;

  final _events = StreamController<RealtimeEvent>.broadcast();
  final http.Client _httpClient;
  final WebSocketChannel Function(Uri uri) _connectChannel;

  WebSocketChannel? _channel;
  Object? _openAttempt;
  StreamSubscription? _channelSubscription;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  bool _channelReady = false;

  /// Call signals queued while the socket is (re)connecting, with the time
  /// they were queued so a stale one — the peer has long since hung up or
  /// retried through a fresh connection — isn't replayed into a new call.
  static const _maxPendingCallSignalAge = Duration(seconds: 30);
  final List<({String payload, DateTime enqueuedAt})> _pendingCallSignals =
      <({String payload, DateTime enqueuedAt})>[];

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
    // A user-initiated disconnect ends any call signaling in flight; queued
    // signals belong to that now-dead session and must not be replayed into
    // whatever connects next.
    _pendingCallSignals.clear();
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
    final encoded = jsonEncode(payload);
    final channel = _channel;
    if (channel == null || !_channelReady) {
      _pendingCallSignals.add((payload: encoded, enqueuedAt: DateTime.now()));
      return;
    }
    try {
      channel.sink.add(encoded);
    } catch (_) {
      _pendingCallSignals.add((payload: encoded, enqueuedAt: DateTime.now()));
    }
  }

  Future<void> dispose() async {
    await disconnect();
    _pendingCallSignals.clear();
    _httpClient.close();
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

    // Identifies this attempt so a superseded open (a newer connect()/_open()
    // call started while this one was still waiting on `ready`) can detect
    // that it lost the race and close its own channel instead of publishing
    // it as `_channel`.
    final attempt = Object();
    _openAttempt = attempt;
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
      // Every (re)connect needs its own ticket: they are single-use and only
      // valid for 30 s, so one can never be reused or fetched ahead of time.
      final wsUri = await _resolveWebSocketUri(
        baseUrl: baseUrl,
        accessToken: accessToken,
      );
      if (!identical(_openAttempt, attempt) || _closedByUser) {
        // Superseded or disconnected while the ticket was in flight; don't
        // open a socket (and burn the ticket) nobody wants any more.
        return;
      }
      final channel = _connectChannel(wsUri);
      // Only publish the channel once `ready` succeeds. Assigning it earlier
      // left `_channel` pointing at a channel whose `ready` could still fail,
      // and closing that channel later in `_closeChannel` never completes
      // (web_socket_channel 3.x: `sink.close()` on a channel whose `ready`
      // failed never resolves), hanging every future disconnect/reconnect.
      await channel.ready;
      if (!identical(_openAttempt, attempt) || _closedByUser) {
        // A newer open() call has already taken over, or disconnect() ran
        // while we were waiting on `ready` (which clears _openAttempt below,
        // but a `ready` that had already resolved by then must still be
        // caught here rather than being published as a live, "connected"
        // socket after the user asked to disconnect). Don't touch shared
        // state, just close the channel we opened.
        unawaited(
          channel.sink
              .close()
              .timeout(const Duration(seconds: 2))
              .catchError((_) {}),
        );
        return;
      }
      _channel = channel;
      _channelReady = true;
      _attempt = 0;
      _flushPendingCallSignals(channel);
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
          _events.add(RealtimeEvent.error(_redactedError(error)));
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
      _events.add(RealtimeEvent.error(_redactedError(error)));
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
    _channelReady = false;
    // Invalidate any open() attempt still waiting on `ready`: without this,
    // a disconnect()/connect() that runs while _open is mid-`ready` leaves
    // _openAttempt pointing at that stale attempt, so it still looks current
    // when `ready` finally resolves and the (now unwanted) channel gets
    // published as `_channel` and reported as connected.
    _openAttempt = null;
    await _channelSubscription?.cancel();
    // Detach state before closing: a channel whose `ready` never succeeded
    // can have a `sink.close()` that never completes, and awaiting that here
    // would hang every subsequent connect()/disconnect() forever.
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      unawaited(
        channel.sink
            .close()
            .timeout(const Duration(seconds: 2))
            .catchError((_) {}),
      );
    }
  }

  void _flushPendingCallSignals(WebSocketChannel channel) {
    if (_pendingCallSignals.isEmpty) return;
    final now = DateTime.now();
    final pending = _pendingCallSignals
        .where(
          (entry) =>
              now.difference(entry.enqueuedAt) <= _maxPendingCallSignalAge,
        )
        .toList();
    _pendingCallSignals.clear();
    for (var index = 0; index < pending.length; index++) {
      try {
        channel.sink.add(pending[index].payload);
      } catch (_) {
        _pendingCallSignals.insertAll(0, pending.sublist(index));
        return;
      }
    }
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
  Uri buildWebSocketUri({required String baseUrl, required String ticket}) {
    return _wsUri(baseUrl, 'ticket', ticket);
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

  @visibleForTesting
  Uri buildLegacyWebSocketUri({
    required String baseUrl,
    required String accessToken,
  }) {
    return _wsUri(baseUrl, 'token', accessToken);
  }

  /// Error text for the event stream. The platform's WebSocket errors quote the
  /// full handshake URL ("Connection to '.../ws?ticket=...' was not upgraded"),
  /// so strip the credential before it can reach state, logs or crash reports.
  static String _redactedError(Object error) =>
      error.toString().replaceAllMapped(
        RegExp(r'([?&](?:ticket|token)=)[^&\s\x27"#]*'),
        (m) => '${m[1]}<redacted>',
      );

  /// Builds the handshake URL for one connect attempt: fetches a fresh
  /// single-use ticket with the access token in the `Authorization` header, so
  /// the token itself never appears in a URL.
  ///
  /// Only a server that has no ticket endpoint (404/405, i.e. older than the
  /// ticket handshake) gets the legacy `?token=` URL. 401, 5xx, timeouts and
  /// network errors propagate to the caller's reconnect backoff instead:
  /// falling back there would put the token in a URL on exactly the paths
  /// (an unhealthy or misconfigured server) where that is least wanted.
  /// A 401 retries through the same backoff, which asks the token provider
  /// again and so picks up a refreshed access token.
  Future<Uri> _resolveWebSocketUri({
    required String baseUrl,
    required String accessToken,
  }) async {
    try {
      final ticket = await _requestWebSocketTicket(
        baseUrl: baseUrl,
        accessToken: accessToken,
      );
      return _wsUri(baseUrl, 'ticket', ticket);
    } on _WebSocketTicketUnsupported {
      return _wsUri(baseUrl, 'token', accessToken);
    }
  }

  Future<String> _requestWebSocketTicket({
    required String baseUrl,
    required String accessToken,
  }) async {
    final normalized = baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    Future<http.Response> post(String base) => _httpClient
        .post(
          Uri.parse('$base/auth/ws-ticket'),
          headers: {'Authorization': 'Bearer $accessToken'},
        )
        .timeout(const Duration(seconds: 8));

    var response = await post(normalized);
    if (response.statusCode == 404 && normalized.endsWith('/api')) {
      // Same fallback as AuthService: /auth is mounted at the server root.
      response = await post(normalized.substring(0, normalized.length - 4));
    }
    if (response.statusCode == 404 || response.statusCode == 405) {
      throw const _WebSocketTicketUnsupported();
    }
    if (response.statusCode != 200) {
      throw StateError(
        'WebSocket ticket request failed (${response.statusCode}).',
      );
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final ticket = decoded['ticket'] as String?;
    if (ticket == null || ticket.isEmpty) {
      throw const FormatException('Invalid WebSocket ticket response.');
    }
    return ticket;
  }

  Uri _wsUri(String baseUrl, String credentialKey, String credential) {
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
    final encoded = Uri.encodeQueryComponent(credential);
    return Uri(
      scheme: scheme,
      host: httpUri.host,
      port: port,
      path: normalizedPath,
      query: '$credentialKey=$encoded',
    );
  }
}
