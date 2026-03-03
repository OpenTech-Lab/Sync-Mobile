import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/realtime_sync_service.dart';

void main() {
  test('buildWebSocketUri uses wss and correct port for https base URL', () {
    final service = RealtimeSyncService();

    final uri = service.buildWebSocketUri(
      baseUrl: 'https://sync.icyanstudio.net',
      accessToken: 'abc',
    );

    expect(uri.scheme, 'wss');
    expect(uri.host, 'sync.icyanstudio.net');
    expect(uri.port, 443);
    expect(uri.path, '/ws');
    expect(uri.queryParameters['token'], 'abc');
  });

  test('buildWebSocketUri preserves explicit port and nested path', () {
    final service = RealtimeSyncService();

    final uri = service.buildWebSocketUri(
      baseUrl: 'http://localhost:8080/api',
      accessToken: 'abc',
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
      accessToken: 'abc',
    );

    expect(uri.scheme, 'wss');
    expect(uri.host, 'sync.icyanstudio.net');
    expect(uri.port, 443);
    expect(uri.path, '/ws');
    expect(uri.fragment, isEmpty);
  });
}
