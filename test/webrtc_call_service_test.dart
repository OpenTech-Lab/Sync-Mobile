import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calls/webrtc_call_service.dart';

void main() {
  test('forces relay transport when TURN is configured', () async {
    final service = WebRtcCallService()
      ..iceServers = const [
        {'urls': 'stun:stun.example.test:3478'},
        {
          'urls': 'turn:turn.example.test:3478',
          'username': 'user',
          'credential': 'credential',
        },
      ];
    addTearDown(service.dispose);

    final configuration = service.peerConnectionConfigurationForTest();

    expect(configuration['iceTransportPolicy'], 'relay');
    expect(configuration['iceServers'], same(service.iceServers));
  });

  test('keeps all candidates for the STUN-only fallback', () async {
    final service = WebRtcCallService();
    addTearDown(service.dispose);

    final configuration = service.peerConnectionConfigurationForTest();

    expect(configuration['iceTransportPolicy'], 'all');
  });

  test('recognizes TURN URLs supplied as a list', () async {
    final service = WebRtcCallService()
      ..iceServers = const [
        {
          'urls': [
            'stun:stun.example.test:3478',
            'turns:turn.example.test:5349?transport=tcp',
          ],
        },
      ];
    addTearDown(service.dispose);

    final configuration = service.peerConnectionConfigurationForTest();

    expect(configuration['iceTransportPolicy'], 'relay');
  });
}
