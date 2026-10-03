import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/models/realtime_event.dart';
import 'package:mobile/services/realtime_sync_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  test('buildWebSocketUri uses wss and correct port for https base URL', () {
    final service = RealtimeSyncService();

    final uri = service.buildWebSocketUri(
      baseUrl: 'https://sync.icyanstudio.net',
      ticket: 'abc',
    );

    expect(uri.scheme, 'wss');
    expect(uri.host, 'sync.icyanstudio.net');
    expect(uri.port, 443);
    expect(uri.path, '/ws');
    expect(uri.queryParameters, {'ticket': 'abc'});
  });

  test('buildWebSocketUri preserves explicit port and nested path', () {
    final service = RealtimeSyncService();

    final uri = service.buildWebSocketUri(
      baseUrl: 'http://localhost:8080/api',
      ticket: 'abc',
    );

    expect(uri.scheme, 'ws');
    expect(uri.host, 'localhost');
    expect(uri.port, 8080);
    expect(uri.path, '/api/ws');
  });

  test('buildWebSocketUri drops invalid :0 and fragment from base URL', () {
    final service = RealtimeSyncService();

    final uri = service.buildWebSocketUri(
      baseUrl: 'https://sync.icyanstudio.net:0#',
      ticket: 'abc',
    );

    expect(uri.scheme, 'wss');
    expect(uri.host, 'sync.icyanstudio.net');
    expect(uri.port, 443);
    expect(uri.path, '/ws');
    expect(uri.fragment, isEmpty);
  });

  test('buildLegacyWebSocketUri keeps the pre-ticket ?token= handshake', () {
    final service = RealtimeSyncService();

    final uri = service.buildLegacyWebSocketUri(
      baseUrl: 'https://sync.icyanstudio.net',
      accessToken: 'abc',
    );

    expect(uri.path, '/ws');
    expect(uri.queryParameters, {'token': 'abc'});
  });

  group('websocket ticket handshake', () {
    const base = 'https://sync.example.test';
    const jwt = 'header.payload.signature-secret';

    late _Harness h;
    setUp(() => h = _Harness());
    tearDown(() => h.dispose());

    test(
      'success: POSTs the token in a header and connects with ?ticket=',
      () async {
        h.respond((_) => _ticketResponse('a' * 64));

        await h.connect(base, jwt);

        expect(h.requests, hasLength(1));
        final request = h.requests.single;
        expect(request.method, 'POST');
        expect(request.url.toString(), '$base/auth/ws-ticket');
        expect(request.headers['Authorization'], 'Bearer $jwt');
        expect(request.url.query, isEmpty);

        final ws = h.connectedUris.single;
        expect(ws.scheme, 'wss');
        expect(ws.path, '/ws');
        expect(ws.queryParameters, {'ticket': 'a' * 64});
        expect(ws.toString(), isNot(contains(jwt)));
        expect(ws.toString(), isNot(contains('token=')));
      },
    );

    for (final status in [404, 405]) {
      test('$status (server has no ticket endpoint): legacy ?token=', () async {
        h.respond((_) => http.Response('', status));

        await h.connect(base, jwt);

        expect(h.connectedUris, hasLength(1));
        expect(h.connectedUris.single.path, '/ws');
        expect(h.connectedUris.single.queryParameters, {'token': jwt});
      });
    }

    final failures = <String, http.Response Function(http.Request)>{
      '401': (_) => http.Response('', 401),
      '403': (_) => http.Response('', 403),
      '429': (_) => http.Response('', 429),
      '500': (_) => http.Response('', 500),
      '503': (_) => http.Response('', 503),
      '200 with an empty ticket': (_) => _ticketResponse(''),
      '200 with a non-JSON body': (_) => http.Response('<html>', 200),
      'a network error': (_) => throw http.ClientException('boom'),
    };
    failures.forEach((name, handler) {
      test(
        '$name: no legacy fallback, error surfaced, reconnect scheduled',
        () async {
          h.respond(handler);

          await h.connect(base, jwt);

          expect(h.connectedUris, isEmpty, reason: 'must not open any socket');
          expect(h.errors, isNotEmpty);
          for (final error in h.errors) {
            expect(error, isNot(contains(jwt)));
          }

          // Normal reconnect backoff: the next attempt asks for a ticket again
          // (and still never falls back to ?token=).
          await h.waitForRequests(2);
          expect(h.connectedUris, isEmpty);
        },
      );
    });

    test('every reconnect fetches a fresh ticket', () async {
      var n = 0;
      h.respond((_) => _ticketResponse('${++n}' * 64));

      await h.connect(base, jwt);
      expect(h.connectedUris.single.queryParameters, {'ticket': '1' * 64});

      // Server drops the socket; the client reconnects through backoff.
      await h.channels.single.closeFromServer();
      await h.waitForRequests(2);
      await h.waitForSockets(2);

      expect(h.requests, hasLength(2));
      expect(h.connectedUris[1].queryParameters, {'ticket': '2' * 64});
      expect(
        h.connectedUris.map((u) => u.queryParameters['ticket']).toSet(),
        hasLength(2),
        reason: 'a ticket is single-use and must never be replayed',
      );
      for (final uri in h.connectedUris) {
        expect(uri.toString(), isNot(contains(jwt)));
      }
    });

    test(
      'a failed handshake error text never contains the ticket or token',
      () async {
        h.respond((_) => _ticketResponse('c' * 64));
        h.channelReadyError = (uri) => WebSocketChannelException(
          "Connection to '$uri' was not upgraded to websocket "
          '(also tried ?token=$jwt&x=1)',
        );

        await h.connect(base, jwt);

        expect(h.errors, isNotEmpty);
        for (final error in h.errors) {
          expect(error, isNot(contains('c' * 64)));
          expect(error, isNot(contains(jwt)));
        }
        expect(h.errors.first, contains('ticket=<redacted>'));
      },
    );

    test(
      'base URL ending in /api retries /auth/ws-ticket at the root',
      () async {
        h.respond(
          (r) => r.url.path == '/api/auth/ws-ticket'
              ? http.Response('', 404)
              : _ticketResponse('d' * 64),
        );

        await h.connect('$base/api', jwt);

        expect(h.requests.map((r) => r.url.path), [
          '/api/auth/ws-ticket',
          '/auth/ws-ticket',
        ]);
        expect(h.connectedUris.single.queryParameters, {'ticket': 'd' * 64});
      },
    );

    test('disconnect while the ticket is in flight opens no socket', () async {
      final gate = Completer<http.Response>();
      h.respondAsync((_) => gate.future);

      final connecting = h.connect(base, jwt);
      await h.waitForRequests(1);
      await h.service.disconnect();
      gate.complete(_ticketResponse('e' * 64));
      await connecting;

      expect(h.connectedUris, isEmpty);
    });
  });

  test('parses room membership changed realtime event', () {
    final service = RealtimeSyncService();

    final event = service.tryParseRealtimeEventForTest(
      payload: '{"type":"room_membership_changed","room_id":"room-123"}',
      currentUserId: 'user-1',
    );

    expect(event, isNotNull);
    expect(event, isA<RealtimeEvent>());
    expect(event!.roomMembershipChangedRoomId, 'room-123');
  });

  test('parses call created acknowledgement event', () {
    final service = RealtimeSyncService();

    final event = service.tryParseRealtimeEventForTest(
      payload:
          '{"type":"call_created","call_id":"call-123","callee_id":"user-2"}',
      currentUserId: 'user-1',
    );

    expect(event, isNotNull);
    expect(event, isA<RealtimeEvent>());
    expect(event!.createdCallId, 'call-123');
    expect(event.createdCallCalleeId, 'user-2');
  });
}

http.Response _ticketResponse(String ticket) =>
    http.Response(jsonEncode({'ticket': ticket, 'expires_in': 30}), 200);

class _Harness {
  _Harness() {
    service = RealtimeSyncService(
      MockClient((request) async {
        requests.add(request);
        return _handler(request);
      }),
      (uri) {
        connectedUris.add(uri);
        final channel = _FakeChannel(channelReadyError?.call(uri));
        channels.add(channel);
        return channel;
      },
    );
    service.events.listen((event) {
      final error = event.error;
      if (error != null) errors.add(error);
    });
  }

  late final RealtimeSyncService service;
  final requests = <http.Request>[];
  final connectedUris = <Uri>[];
  final channels = <_FakeChannel>[];
  final errors = <String>[];
  Object Function(Uri uri)? channelReadyError;
  late FutureOr<http.Response> Function(http.Request) _handler;

  void respond(http.Response Function(http.Request) handler) =>
      _handler = handler;
  void respondAsync(Future<http.Response> Function(http.Request) handler) =>
      _handler = handler;

  Future<void> connect(String baseUrl, String token) async {
    await service.connect(
      baseUrl: baseUrl,
      accessTokenProvider: () async => token,
      currentUserId: 'user-1',
    );
    // The events stream delivers asynchronously; let listeners see them.
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> waitForRequests(int count) =>
      _waitFor(() => requests.length >= count, 'requests >= $count');
  Future<void> waitForSockets(int count) =>
      _waitFor(() => connectedUris.length >= count, 'sockets >= $count');

  Future<void> _waitFor(bool Function() done, String what) async {
    final deadline = DateTime.now().add(const Duration(seconds: 6));
    while (!done()) {
      if (DateTime.now().isAfter(deadline)) {
        throw TimeoutException('timed out waiting for $what');
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  Future<void> dispose() => service.dispose();
}

/// Just enough of a [WebSocketChannel] for the service: `ready`, a stream the
/// "server" can close, and a sink that swallows writes.
class _FakeChannel implements WebSocketChannel {
  _FakeChannel(Object? readyError) {
    if (readyError != null) {
      _ready.future.ignore();
      _ready.completeError(readyError);
    } else {
      _ready.complete();
    }
  }

  final _ready = Completer<void>();
  final _incoming = StreamController<dynamic>();

  Future<void> closeFromServer() => _incoming.close();

  @override
  Future<void> get ready => _ready.future;
  @override
  Stream get stream => _incoming.stream;
  @override
  WebSocketSink get sink => _FakeSink();
  @override
  String? get protocol => null;
  @override
  int? get closeCode => null;
  @override
  String? get closeReason => null;

  // Only the members above are exercised; fail loudly on anything else.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSink implements WebSocketSink {
  @override
  void add(dynamic data) {}
  @override
  void addError(Object error, [StackTrace? stackTrace]) {}
  @override
  Future addStream(Stream stream) async {}
  @override
  Future close([int? closeCode, String? closeReason]) async {}
  @override
  Future get done async {}
}
