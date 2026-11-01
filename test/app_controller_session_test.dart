import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/services/auth_service.dart';
import 'package:mobile/services/session_storage.dart';
import 'package:mobile/state/app_controller.dart';

const _serverUrl = 'https://sync.example';

String _jwt(DateTime expiry) {
  String encode(String json) =>
      base64Url.encode(utf8.encode(json)).replaceAll('=', '');
  final exp = expiry.millisecondsSinceEpoch ~/ 1000;
  return '${encode('{"alg":"HS256"}')}.${encode('{"sub":"me","exp":$exp}')}.sig';
}

final _expiredToken = _jwt(DateTime.now().subtract(const Duration(hours: 1)));
final _newToken = _jwt(DateTime.now().add(const Duration(hours: 1)));

/// Records every refresh token presented: the real server revokes the whole
/// token family when one is presented twice.
class _FakeAuthService extends AuthService {
  _FakeAuthService({this.error});

  final Object? error;
  final gate = Completer<void>();
  final presented = <String>[];

  @override
  Future<AuthTokens> refresh({
    required String baseUrl,
    required String refreshToken,
  }) async {
    presented.add(refreshToken);
    await gate.future;
    final failure = error;
    if (failure != null) throw failure;
    return AuthTokens(accessToken: _newToken, refreshToken: 'refresh-2');
  }
}

class _MemorySessionStorage extends SessionStorage {
  _MemorySessionStorage({this.refreshToken = 'refresh-1'});

  String? refreshToken;
  int writes = 0;
  int clears = 0;

  @override
  Future<String?> readRefreshToken(String serverUrl) async => refreshToken;

  @override
  Future<void> writeTokens({
    required String serverUrl,
    required String accessToken,
    required String refreshToken,
  }) async {
    writes++;
    this.refreshToken = refreshToken;
  }

  @override
  Future<void> clearTokens(String serverUrl) async {
    clears++;
    refreshToken = null;
  }
}

class _SeededAppController extends AppController {
  _SeededAppController(AuthService auth, SessionStorage storage)
    : super(authService: auth, sessionStorage: storage);

  @override
  Future<AppState> build() async => AppState(
    serverUrl: _serverUrl,
    accessToken: _expiredToken,
    currentUserId: 'me',
    currentUsername: 'me',
    savedUserId: 'me',
    connectionStatus: ConnectionStatus.idle,
    connectionError: null,
    planetInfo: null,
    isSubmitting: false,
    authError: null,
  );
}

Future<ProviderContainer> _container(
  _FakeAuthService auth,
  _MemorySessionStorage storage,
) async {
  final container = ProviderContainer(
    overrides: [
      appControllerProvider.overrideWith(
        () => _SeededAppController(auth, storage),
      ),
    ],
  );
  addTearDown(container.dispose);
  await container.read(appControllerProvider.future);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('concurrent refreshes (Sync-Mobile #3)', () {
    test(
      'concurrent ensureFreshAccessToken calls share one refresh, write tokens '
      'once and all get the new token',
      () async {
        final auth = _FakeAuthService();
        final storage = _MemorySessionStorage();
        final container = await _container(auth, storage);
        final controller = container.read(appControllerProvider.notifier);

        final callers = Future.wait([
          for (var i = 0; i < 5; i++) controller.ensureFreshAccessToken(),
        ]);
        await pumpEventQueue();
        auth.gate.complete();
        final results = await callers;

        expect(auth.presented, ['refresh-1']);
        expect(storage.writes, 1);
        expect(results, everyElement(_newToken));
        expect(
          container.read(appControllerProvider).value!.accessToken,
          _newToken,
        );
      },
    );

    test('resume and ensureFreshAccessToken share one refresh too', () async {
      final auth = _FakeAuthService();
      final storage = _MemorySessionStorage();
      final container = await _container(auth, storage);
      final controller = container.read(appControllerProvider.notifier);

      final resume = controller.verifySessionOnResume();
      final fresh = controller.ensureFreshAccessToken();
      await pumpEventQueue();
      auth.gate.complete();

      expect(await resume, isTrue);
      expect(await fresh, _newToken);
      expect(auth.presented, ['refresh-1']);
    });

    test('a later refresh presents the rotated token', () async {
      final auth = _FakeAuthService()..gate.complete();
      final storage = _MemorySessionStorage();
      final container = await _container(auth, storage);
      final controller = container.read(appControllerProvider.notifier);

      await controller.ensureFreshAccessToken();
      // Force another round now that the in-flight slot is free.
      controller.state = AsyncData(
        controller.state.value!.copyWith(accessToken: _expiredToken),
      );
      await controller.ensureFreshAccessToken();

      expect(auth.presented, ['refresh-1', 'refresh-2']);
    });

    test('a failed refresh gives every caller the old token and can be '
        'retried', () async {
      final auth = _FakeAuthService(error: const TokenRefreshException(503));
      final storage = _MemorySessionStorage();
      final container = await _container(auth, storage);
      final controller = container.read(appControllerProvider.notifier);

      final callers = Future.wait([
        controller.ensureFreshAccessToken(),
        controller.ensureFreshAccessToken(),
      ]);
      await pumpEventQueue();
      auth.gate.complete();

      expect(await callers, everyElement(_expiredToken));
      expect(auth.presented, hasLength(1));
      expect(storage.writes, 0);

      await controller.ensureFreshAccessToken();
      expect(auth.presented, hasLength(2));
    });
  });

  group('verifySessionOnResume', () {
    for (final status in [401, 403]) {
      test('$status ends the session', () async {
        final auth = _FakeAuthService(error: TokenRefreshException(status))
          ..gate.complete();
        final storage = _MemorySessionStorage();
        final container = await _container(auth, storage);

        final valid = await container
            .read(appControllerProvider.notifier)
            .verifySessionOnResume();

        expect(valid, isFalse);
        expect(storage.clears, 1);
        expect(container.read(appControllerProvider).value!.accessToken, '');
      });
    }

    for (final status in [500, 502, 503, 429]) {
      test('$status keeps the session', () async {
        final auth = _FakeAuthService(error: TokenRefreshException(status))
          ..gate.complete();
        final storage = _MemorySessionStorage();
        final container = await _container(auth, storage);

        final valid = await container
            .read(appControllerProvider.notifier)
            .verifySessionOnResume();

        expect(valid, isTrue);
        expect(storage.clears, 0);
        expect(storage.refreshToken, 'refresh-1');
        expect(
          container.read(appControllerProvider).value!.accessToken,
          _expiredToken,
        );
      });
    }

    test('a network error keeps the session', () async {
      final auth = _FakeAuthService(error: const SocketException('offline'))
        ..gate.complete();
      final storage = _MemorySessionStorage();
      final container = await _container(auth, storage);

      final valid = await container
          .read(appControllerProvider.notifier)
          .verifySessionOnResume();

      expect(valid, isTrue);
      expect(storage.clears, 0);
    });

    test('no stored refresh token ends the session', () async {
      final auth = _FakeAuthService()..gate.complete();
      final storage = _MemorySessionStorage(refreshToken: null);
      final container = await _container(auth, storage);

      final valid = await container
          .read(appControllerProvider.notifier)
          .verifySessionOnResume();

      expect(valid, isFalse);
      expect(auth.presented, isEmpty);
    });
  });

  test('AuthService.refresh reports the HTTP status of a failed refresh', () {
    final service = AuthService(
      MockClient((_) async => http.Response('bad gateway', 502)),
    );

    expect(
      service.refresh(baseUrl: _serverUrl, refreshToken: 'r'),
      throwsA(
        isA<TokenRefreshException>()
            .having((e) => e.statusCode, 'statusCode', 502)
            .having((e) => e.isSessionRejected, 'isSessionRejected', false),
      ),
    );
  });
}
