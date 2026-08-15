import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'call_controller.dart';

/// Thin bridge between native CallKit/PushKit events and [CallController].
///
/// Listens to [FlutterCallkitIncoming.onEvent] and translates the events
/// fired when the user interacts with the native incoming-call UI (which,
/// on a cold launch, is the *only* signal the app gets — there is no
/// WebSocket connection yet) into the equivalent [CallController] calls.
///
/// iOS only: Android has no CallKit-equivalent wired up in this phase
/// (FCM/push transport for Android is Phase 2), so [start] is a no-op there.
class CallkitService {
  CallkitService(this._ref);

  final Ref _ref;
  StreamSubscription<CallEvent?>? _subscription;

  void start() {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    _subscription ??= FlutterCallkitIncoming.onEvent.listen(_handleEvent);
    unawaited(_resumeAnyActiveCall());
  }

  /// On a cold launch triggered by tapping Accept on the native CallKit UI,
  /// the ACTION_CALL_ACCEPT event fires natively before this Dart isolate has
  /// subscribed to [FlutterCallkitIncoming.onEvent] (the event channel has no
  /// buffering — events sent with nobody listening are simply dropped), so
  /// the call would otherwise be silently lost. CallKit itself keeps the
  /// answered call tracked regardless, so check for one on every start and
  /// resume it the same way an in-time accept event would.
  Future<void> _resumeAnyActiveCall() async {
    final List<CallKitParams> active;
    try {
      active = await FlutterCallkitIncoming.activeCalls();
    } catch (_) {
      return;
    }
    // Only resume calls CallKit itself marked answered (isAccepted, set by
    // provider(_:perform: CXAnswerCallAction) natively) — a still-ringing
    // call is also "active" and must not be auto-connected just because the
    // app happened to launch while it was ringing.
    final answered = active.where((call) => call.isAccepted);
    if (answered.isEmpty) return;
    final callKitParams = answered.first;
    final extra = callKitParams.extra ?? const <String, dynamic>{};
    _ref.read(callControllerProvider.notifier).resumeCallFromPush(
          callId: callKitParams.id,
          callerId: (extra['caller_id'] as String?) ?? '',
          callerDisplayName:
              callKitParams.nameCaller ?? callKitParams.handle ?? 'Unknown',
          callType: (extra['call_type'] as String?) ??
              (callKitParams.type == 1 ? 'video' : 'voice'),
        );
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }

  void _handleEvent(CallEvent? event) {
    if (event == null) return;
    final controller = _ref.read(callControllerProvider.notifier);

    switch (event) {
      case CallEventActionCallAccept(:final callKitParams):
        final extra = callKitParams.extra ?? const <String, dynamic>{};
        controller.resumeCallFromPush(
          callId: callKitParams.id,
          callerId: (extra['caller_id'] as String?) ?? '',
          callerDisplayName:
              callKitParams.nameCaller ?? callKitParams.handle ?? 'Unknown',
          callType: (extra['call_type'] as String?) ??
              (callKitParams.type == 1 ? 'video' : 'voice'),
        );
      case CallEventActionCallDecline(:final callKitParams):
        _rejectIfCurrent(callKitParams.id);
      case CallEventActionCallEnded(:final callKitParams):
        _hangupIfCurrent(callKitParams.id);
      case CallEventActionCallTimeout(:final id):
        _rejectIfCurrent(id);
      default:
        // ACTION_CALL_START / TOGGLE_* / DID_UPDATE_DEVICE_PUSH_TOKEN_VOIP /
        // etc. carry no action CallController needs to take.
        break;
    }
  }

  void _rejectIfCurrent(String callId) {
    final current = _ref.read(callControllerProvider).valueOrNull;
    if (current == null || current.callId != callId) return;
    _ref.read(callControllerProvider.notifier).rejectCall();
  }

  void _hangupIfCurrent(String callId) {
    final current = _ref.read(callControllerProvider).valueOrNull;
    if (current == null || current.callId != callId) return;
    _ref.read(callControllerProvider.notifier).hangup();
  }
}

final callkitServiceProvider = Provider<CallkitService>((ref) {
  final service = CallkitService(ref);
  ref.onDispose(service.dispose);
  return service;
});
