import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/models/friend_qr_payload.dart';

void main() {
  test('parses JSON friend QR payload', () {
    const raw =
        '{"type":"sync_friend","user_id":"abc-123","server_url":"https://sync.example"}';

    final payload = FriendQrPayload.tryParse(raw);

    expect(payload, isNotNull);
    expect(payload!.userId, 'abc-123');
    expect(payload.serverUrl, 'https://sync.example');
  });

  test('parses sync URI friend QR payload', () {
    const raw =
        'sync://friend?user_id=abc-123&server_url=https%3A%2F%2Fsync.example';

    final payload = FriendQrPayload.tryParse(raw);

    expect(payload, isNotNull);
    expect(payload!.userId, 'abc-123');
    expect(payload.serverUrl, 'https://sync.example');
  });

  test('parses plain HTTPS friend link payload', () {
    const raw = 'https://sync.icyanstudio.net/e9606888-c193-47d4-9845-4cae9d273620';

    final payload = FriendQrPayload.tryParse(raw);

    expect(payload, isNotNull);
    expect(payload!.userId, 'e9606888-c193-47d4-9845-4cae9d273620');
    expect(payload.serverUrl, 'https://sync.icyanstudio.net');
  });

  test('returns null for unsupported payload', () {
    final payload = FriendQrPayload.tryParse('not-a-valid-qr-payload');

    expect(payload, isNull);
  });
}
