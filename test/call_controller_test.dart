import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:mobile/features/calls/call_controller.dart';
import 'package:mobile/features/calls/webrtc_call_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'coalesces native and in-app acceptance into one WebRTC answer',
    () async {
      final service = _GatedAnswerService();
      final container = ProviderContainer(
        overrides: [webRtcCallServiceProvider.overrideWithValue(service)],
      );
      addTearDown(() async {
        container.dispose();
        await service.dispose();
      });
      await container.read(callControllerProvider.future);
      final controller = container.read(callControllerProvider.notifier);
      controller.handleIncomingCall(
        callId: 'call-1',
        callerId: 'caller-1',
        callerDisplayName: 'Caller',
        callType: 'voice',
        sdpOffer: 'offer',
      );

      final nativeAccept = controller.acceptCall();
      final inAppAccept = controller.acceptCall();
      expect(identical(nativeAccept, inAppAccept), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(service.createAnswerCount, 1);

      service.release.complete();
      await expectLater(nativeAccept, throwsStateError);
      await expectLater(inAppAccept, throwsStateError);
      expect(container.read(callControllerProvider).valueOrNull, isNull);
    },
  );
}

class _GatedAnswerService extends WebRtcCallService {
  final release = Completer<void>();
  int createAnswerCount = 0;

  @override
  Future<({MediaStream localStream, Future<String> sdpAnswer})> createAnswer({
    required String sdpOffer,
    required bool withVideo,
  }) async {
    createAnswerCount += 1;
    await release.future;
    throw StateError('stop after proving the single-flight guard');
  }
}
