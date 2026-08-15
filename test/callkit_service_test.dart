import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calls/call_controller.dart';
import 'package:mobile/features/calls/call_models.dart';
import 'package:mobile/features/calls/callkit_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const nativeChannel = MethodChannel('sync.notifications');

  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(nativeChannel, null);
  });

  test('cold-start service consumes the native persisted acceptance', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final controller = _RecordingCallController();
    final container = ProviderContainer(
      overrides: [callControllerProvider.overrideWith(() => controller)],
    );
    addTearDown(container.dispose);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(nativeChannel, (call) async {
          if (call.method == 'getPendingAcceptedCall') {
            return <String, dynamic>{
              'call_id': 'call-1',
              'caller_id': 'caller-1',
              'caller_display_name': 'Caller',
              'call_type': 'video',
            };
          }
          return null;
        });

    container.read(callkitServiceProvider).start();
    final resumed = await controller.resumed.future.timeout(
      const Duration(seconds: 1),
    );

    expect(resumed.callId, 'call-1');
    expect(resumed.callerId, 'caller-1');
    expect(resumed.callerDisplayName, 'Caller');
    expect(resumed.callType, 'video');
  });
}

class _RecordingCallController extends CallController {
  final resumed =
      Completer<
        ({
          String callId,
          String callerId,
          String callerDisplayName,
          String callType,
        })
      >();

  @override
  Future<CallInfo?> build() async => null;

  @override
  Future<void> resumeCallFromPush({
    required String callId,
    required String callerId,
    required String callerDisplayName,
    required String callType,
  }) async {
    if (!resumed.isCompleted) {
      resumed.complete((
        callId: callId,
        callerId: callerId,
        callerDisplayName: callerDisplayName,
        callType: callType,
      ));
    }
  }
}
