import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/services/app_secure_storage.dart';
import 'package:mobile/services/auth_service.dart';
import 'package:mobile/services/message_e2ee_service.dart';

// RFC 7748 section 6.1 X25519 keys. The device is "Alice"; the server's
// ephemeral key is "Bob". The proof below was computed the way the server's
// verify_device_login_proof does: HMAC-SHA256 keyed with the X25519 shared
// secret (server side: Bob's private x Alice's public), over
// "device-login:<challenge_id>:<device pubkey>", base64 (and cross-checked
// with `openssl pkeyutl -derive` + `openssl dgst -hmac`).
const _devicePrivateSeedBase64 = 'dwdtCnMYpX08FsFyUbJmRd9ML4frwJkqsXf7pR25LCo=';
const _devicePublicKeyBase64 = 'hSDwCYkwp1R0i33ctD73Wg2/Og0mOBr066SpjqqbTmo=';
const _serverEphemeralPublicKeyBase64 =
    '3p7bfXt9wbTTW2HC7OQ1Nz+DQ8hbeGdNrfx+FG+IK08=';
final _challengeId = '0123456789abcdef' * 4;
const _expectedProof = '0cHsiV+Fx+3M8EV5wAK+t32Ef0GHE7WYGDVN/EAbV7g=';

const _accessSecret = 'access-token-secret-value';
const _refreshSecret = 'refresh-token-secret-value';
const _qrSecret = 'qr-secret-value/+=';

class _MemoryStorage extends AppSecureStorage {
  _MemoryStorage(this._values);
  final Map<String, String> _values;

  @override
  Future<String?> read({required String key}) async => _values[key];

  @override
  Future<void> write({required String key, required String? value}) async {
    if (value == null) {
      _values.remove(key);
    } else {
      _values[key] = value;
    }
  }
}

http.Response _json(int status, Object body) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

http.Response _challenge() => _json(200, {
  'challenge_id': _challengeId,
  'server_ephemeral_pubkey': _serverEphemeralPublicKeyBase64,
  'expires_in': 60,
});

http.Response _tokens() => _json(200, {
  'access_token': _accessSecret,
  'refresh_token': _refreshSecret,
});

void main() {
  group('createDeviceLoginProof', () {
    test('matches the proof the server verifies for the same keys', () async {
      final service = MessageE2eeService(
        secureStorage: _MemoryStorage({
          'chat_e2ee_seed_v1': _devicePrivateSeedBase64,
        }),
      );

      final proof = await service.createDeviceLoginProof(
        challengeId: _challengeId,
        serverEphemeralPublicKeyBase64: _serverEphemeralPublicKeyBase64,
        devicePublicKeyBase64: _devicePublicKeyBase64,
      );

      expect(proof, _expectedProof);
    });

    test('rejects a server key that is not 32 bytes', () async {
      final service = MessageE2eeService(
        secureStorage: _MemoryStorage({
          'chat_e2ee_seed_v1': _devicePrivateSeedBase64,
        }),
      );

      expect(
        service.createDeviceLoginProof(
          challengeId: _challengeId,
          serverEphemeralPublicKeyBase64: base64Encode(List.filled(31, 1)),
          devicePublicKeyBase64: _devicePublicKeyBase64,
        ),
        throwsFormatException,
      );
    });
  });

  group('deviceLogin', () {
    late List<http.Request> requests;

    AuthService serviceFor(http.Response Function(http.Request) handler) {
      requests = [];
      return AuthService(
        MockClient((request) async {
          requests.add(request);
          return handler(request);
        }),
      );
    }

    Future<AuthTokens> login(AuthService service, {String? baseUrl}) =>
        service.deviceLogin(
          baseUrl: baseUrl ?? 'https://sync.example.test',
          deviceAuthPublicKey: _devicePublicKeyBase64,
          createProof: (challenge) async {
            expect(challenge.challengeId, _challengeId);
            expect(
              challenge.serverEphemeralPublicKey,
              _serverEphemeralPublicKeyBase64,
            );
            return _expectedProof;
          },
        );

    Map<String, dynamic> bodyOf(http.Request r) =>
        jsonDecode(r.body) as Map<String, dynamic>;

    test('challenge supported: logs in with challenge_id and proof', () async {
      final service = serviceFor(
        (r) => r.url.path.endsWith('/device-login/challenge')
            ? _challenge()
            : _tokens(),
      );

      final tokens = await login(service);

      expect(tokens.accessToken, _accessSecret);
      expect(requests.map((r) => r.url.path), [
        '/auth/device-login/challenge',
        '/auth/device-login',
      ]);
      expect(bodyOf(requests[0]), {
        'device_auth_pubkey': _devicePublicKeyBase64,
      });
      expect(bodyOf(requests[1]), {
        'device_auth_pubkey': _devicePublicKeyBase64,
        'challenge_id': _challengeId,
        'proof': _expectedProof,
      });
    });

    for (final status in [404, 405]) {
      test(
        'challenge endpoint $status: falls back to the legacy body',
        () async {
          final service = serviceFor(
            (r) => r.url.path.endsWith('/device-login/challenge')
                ? http.Response('', status)
                : _tokens(),
          );

          final tokens = await login(service);

          expect(tokens.accessToken, _accessSecret);
          expect(requests.last.url.path, '/auth/device-login');
          expect(bodyOf(requests.last), {
            'device_auth_pubkey': _devicePublicKeyBase64,
          });
        },
      );
    }

    test('/api base: 404 only counts after the root retry', () async {
      // New server mounted at the root: /api/auth/... is 404, root answers.
      final service = serviceFor((r) {
        if (r.url.path.startsWith('/api/')) return http.Response('', 404);
        return r.url.path.endsWith('/device-login/challenge')
            ? _challenge()
            : _tokens();
      });

      await login(service, baseUrl: 'https://sync.example.test/api');

      final loginBody = bodyOf(requests.last);
      expect(requests.last.url.path, '/auth/device-login');
      expect(loginBody['challenge_id'], _challengeId);
      expect(loginBody['proof'], _expectedProof);
      expect(requests.map((r) => r.url.path), [
        '/api/auth/device-login/challenge',
        '/auth/device-login/challenge',
        '/api/auth/device-login',
        '/auth/device-login',
      ]);
    });

    test('/api base: old server (404 at both) gets the legacy body', () async {
      final service = serviceFor(
        (r) => r.url.path.endsWith('/device-login/challenge')
            ? http.Response('', 404)
            : _tokens(),
      );

      await login(service, baseUrl: 'https://sync.example.test/api');

      expect(bodyOf(requests.last).containsKey('challenge_id'), isFalse);
      expect(bodyOf(requests.last).containsKey('proof'), isFalse);
    });

    for (final status in [400, 401, 403, 429, 500, 503]) {
      test('challenge $status: error, no legacy login attempt', () async {
        final service = serviceFor((_) => http.Response('', status));

        await expectLater(login(service), throwsA(isA<StateError>()));

        expect(requests.map((r) => r.url.path), [
          '/auth/device-login/challenge',
        ]);
      });
    }

    test('challenge network error: error, no legacy login attempt', () async {
      requests = [];
      final service = AuthService(
        MockClient((request) async {
          requests.add(request);
          throw http.ClientException('connection reset', request.url);
        }),
      );

      await expectLater(login(service), throwsA(isA<StateError>()));

      expect(
        requests.every((r) => r.url.path.endsWith('/device-login/challenge')),
        isTrue,
      );
    });

    for (final body in ['not json', '[]', '{}']) {
      test('malformed challenge response ($body): error, no legacy', () async {
        final service = serviceFor((_) => http.Response(body, 200));

        await expectLater(login(service), throwsFormatException);

        expect(requests.map((r) => r.url.path), [
          '/auth/device-login/challenge',
        ]);
      });
    }

    test(
      'login rejected after a challenge: no second, legacy attempt',
      () async {
        final service = serviceFor(
          (r) => r.url.path.endsWith('/device-login/challenge')
              ? _challenge()
              : http.Response('', 404),
        );

        await expectLater(login(service), throwsA(isA<StateError>()));

        expect(
          requests.where((r) => r.url.path == '/auth/device-login'),
          hasLength(1),
        );
      },
    );

    test(
      'proof failure after a challenge: error, nothing else is sent',
      () async {
        final service = serviceFor((_) => _challenge());

        await expectLater(
          service.deviceLogin(
            baseUrl: 'https://sync.example.test',
            deviceAuthPublicKey: _devicePublicKeyBase64,
            createProof: (_) async => throw StateError('no identity'),
          ),
          throwsA(isA<StateError>()),
        );

        expect(requests, hasLength(1));
      },
    );

    test('error text carries no proof, key or token', () async {
      final service = serviceFor(
        (r) => r.url.path.endsWith('/device-login/challenge')
            ? _challenge()
            : http.Response(jsonEncode({'proof': _expectedProof}), 401),
      );

      final error = await login(
        service,
      ).then<Object>((_) => fail('expected failure'), onError: (Object e) => e);

      for (final secret in [_expectedProof, _accessSecret, _refreshSecret]) {
        expect(error.toString(), isNot(contains(secret)));
      }
    });
  });

  group('pollQrLoginSession', () {
    late List<http.Request> requests;

    AuthService serviceFor(http.Response Function(http.Request) handler) {
      requests = [];
      return AuthService(
        MockClient((request) async {
          requests.add(request);
          return handler(request);
        }),
      );
    }

    Future<QrLoginStatus> poll(AuthService service, {String? baseUrl}) =>
        service.pollQrLoginSession(
          baseUrl: baseUrl ?? 'https://sync.example.test',
          sessionId: 'sess-1',
          secret: _qrSecret,
        );

    test('POSTs the secret in the body, never in the URL', () async {
      final service = serviceFor(
        (_) => _json(200, {
          'status': 'approved',
          'access_token': _accessSecret,
          'refresh_token': _refreshSecret,
        }),
      );

      final status = await poll(service);

      expect(status.isApproved, isTrue);
      expect(status.accessToken, _accessSecret);
      expect(requests, hasLength(1));
      expect(requests.single.method, 'POST');
      expect(requests.single.url.path, '/auth/qr-login/session/sess-1');
      expect(requests.single.url.hasQuery, isFalse);
      expect(jsonDecode(requests.single.body), {'secret': _qrSecret});
    });

    for (final status in [404, 405]) {
      test('POST $status: falls back to the legacy GET ?secret=', () async {
        final service = serviceFor(
          (r) => r.method == 'POST'
              ? http.Response('', status)
              : _json(200, {'status': 'pending'}),
        );

        final result = await poll(service);

        expect(result.isPending, isTrue);
        expect(requests.map((r) => r.method), ['POST', 'GET']);
        expect(requests.last.url.path, '/auth/qr-login/session/sess-1');
        expect(requests.last.url.queryParameters, {'secret': _qrSecret});
      });
    }

    test(
      '/api base: POST retries at the root before the GET fallback',
      () async {
        final service = serviceFor((r) {
          if (r.url.path.startsWith('/api/')) return http.Response('', 404);
          return _json(200, {'status': 'pending'});
        });

        final result = await poll(
          service,
          baseUrl: 'https://sync.example.test/api',
        );

        expect(result.isPending, isTrue);
        expect(requests.map((r) => '${r.method} ${r.url.path}'), [
          'POST /api/auth/qr-login/session/sess-1',
          'POST /auth/qr-login/session/sess-1',
        ]);
      },
    );

    test('/api base, old server: root POST 405 then GET', () async {
      final service = serviceFor((r) {
        if (r.method == 'GET' && !r.url.path.startsWith('/api/')) {
          return _json(200, {'status': 'expired'});
        }
        return http.Response('', r.url.path.startsWith('/api/') ? 404 : 405);
      });

      final result = await poll(
        service,
        baseUrl: 'https://sync.example.test/api',
      );

      expect(result.isExpired, isTrue);
      expect(requests.map((r) => '${r.method} ${r.url.path}'), [
        'POST /api/auth/qr-login/session/sess-1',
        'POST /auth/qr-login/session/sess-1',
        'GET /api/auth/qr-login/session/sess-1',
        'GET /auth/qr-login/session/sess-1',
      ]);
    });

    for (final status in [401, 429, 500]) {
      test('POST $status: error, no legacy GET', () async {
        final service = serviceFor((_) => http.Response('', status));

        await expectLater(poll(service), throwsA(isA<StateError>()));

        expect(requests.map((r) => r.method), ['POST']);
      });
    }

    test('POST network error: propagates, no legacy GET', () async {
      requests = [];
      final service = AuthService(
        MockClient((request) async {
          requests.add(request);
          throw http.ClientException('connection reset', request.url);
        }),
      );

      await expectLater(poll(service), throwsA(isA<http.ClientException>()));

      expect(requests.map((r) => r.method), ['POST']);
    });

    test('legacy GET transport error text does not quote the secret', () async {
      requests = [];
      final service = AuthService(
        MockClient((request) async {
          requests.add(request);
          if (request.method == 'POST') return http.Response('', 404);
          throw http.ClientException('connection reset', request.url);
        }),
      );

      final error = await poll(
        service,
      ).then<Object>((_) => fail('expected failure'), onError: (Object e) => e);

      expect(error, isA<StateError>());
      expect(error.toString(), contains('secret=<redacted>'));
      expect(error.toString(), isNot(contains('secret-value')));
      expect(
        error.toString(),
        isNot(contains(Uri.encodeQueryComponent(_qrSecret))),
      );
    });
  });
}
