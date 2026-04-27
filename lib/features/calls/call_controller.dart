import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../state/realtime_sync_controller.dart';
import 'call_models.dart';
import 'webrtc_call_service.dart';

final webRtcCallServiceProvider = Provider<WebRtcCallService>((ref) {
  final svc = WebRtcCallService();
  ref.onDispose(svc.dispose);
  return svc;
});

final callControllerProvider =
    AsyncNotifierProvider<CallController, CallInfo?>(CallController.new);

class CallController extends AsyncNotifier<CallInfo?> {
  Timer? _noAnswerTimer;

  @override
  Future<CallInfo?> build() async => null;

  // ── Outgoing call ──────────────────────────────────────────────────────────

  Future<void> startCall({
    required String peerId,
    required String peerDisplayName,
    required CallType callType,
  }) async {
    final svc = ref.read(webRtcCallServiceProvider);

    svc.onIceCandidate = (c) => _sendIceCandidate(c, peerId);
    svc.onRemoteStream = _onRemoteStream;
    svc.onConnectionFailed = hangup;

    final (:localStream, :sdpOffer) =
        await svc.createOffer(withVideo: callType == CallType.video);

    // Use a placeholder call ID until the server echoes back the real one
    // via the callee's incoming_call event. The server's CallAnswer relay
    // will carry the real call_id which we update in handleCallAnswered.
    const tempCallId = 'pending';
    state = AsyncData(CallInfo(
      callId: tempCallId,
      peerId: peerId,
      peerDisplayName: peerDisplayName,
      callType: callType,
      direction: CallDirection.outgoing,
      phase: CallPhase.calling,
      localStream: localStream,
    ));

    ref.read(realtimeSyncControllerProvider.notifier).sendCallSignal({
      'type': 'call_offer',
      'callee_id': peerId,
      'call_type': callType == CallType.voice ? 'voice' : 'video',
      'sdp_offer': sdpOffer,
    });

    // Hang up automatically if callee doesn't answer within 45 s
    _noAnswerTimer?.cancel();
    _noAnswerTimer = Timer(const Duration(seconds: 45), () {
      final current = state.valueOrNull;
      if (current != null && current.phase == CallPhase.calling) {
        hangup();
      }
    });
  }

  // ── Incoming call — accept ─────────────────────────────────────────────────

  Future<void> acceptCall() async {
    final current = state.valueOrNull;
    if (current == null || current.phase != CallPhase.ringing) return;

    final svc = ref.read(webRtcCallServiceProvider);

    svc.onIceCandidate = (c) => _sendIceCandidate(c, current.peerId);
    svc.onRemoteStream = _onRemoteStream;
    svc.onConnectionFailed = hangup;

    final (:localStream, :sdpAnswer) = await svc.createAnswer(
      sdpOffer: current.sdpOffer!,
      withVideo: current.callType == CallType.video,
    );

    state = AsyncData(current.copyWith(
      phase: CallPhase.connecting,
      localStream: localStream,
    ));

    ref.read(realtimeSyncControllerProvider.notifier).sendCallSignal({
      'type': 'call_answer',
      'call_id': current.callId,
      'caller_id': current.peerId,
      'sdp_answer': sdpAnswer,
    });
  }

  // ── Incoming call — reject ─────────────────────────────────────────────────

  void rejectCall() {
    final current = state.valueOrNull;
    if (current == null) return;

    ref.read(realtimeSyncControllerProvider.notifier).sendCallSignal({
      'type': 'call_reject',
      'call_id': current.callId,
      'caller_id': current.peerId,
    });

    ref.read(webRtcCallServiceProvider).dispose();
    state = const AsyncData(null);
  }

  // ── Hang up ────────────────────────────────────────────────────────────────

  void hangup() {
    _noAnswerTimer?.cancel();
    _noAnswerTimer = null;
    final current = state.valueOrNull;
    if (current == null) return;

    ref.read(realtimeSyncControllerProvider.notifier).sendCallSignal({
      'type': 'call_hangup',
      'call_id': current.callId,
      'peer_id': current.peerId,
    });

    ref.read(webRtcCallServiceProvider).dispose();
    state = const AsyncData(null);
  }

  // ── Media controls ─────────────────────────────────────────────────────────

  void toggleMute() {
    final current = state.valueOrNull;
    if (current == null) return;
    final next = !current.isMuted;
    ref.read(webRtcCallServiceProvider).setMuted(next);
    state = AsyncData(current.copyWith(isMuted: next));
  }

  void toggleCamera() {
    final current = state.valueOrNull;
    if (current == null) return;
    final next = !current.isCameraOff;
    ref.read(webRtcCallServiceProvider).setCameraEnabled(!next);
    state = AsyncData(current.copyWith(isCameraOff: next));
  }

  // ── Inbound signaling handlers ─────────────────────────────────────────────

  void handleIncomingCall({
    required String callId,
    required String callerId,
    required String callerDisplayName,
    required String callType,
    required String sdpOffer,
  }) {
    final current = state.valueOrNull;
    // Auto-reject if already in a call
    if (current != null && current.phase != CallPhase.idle) {
      ref.read(realtimeSyncControllerProvider.notifier).sendCallSignal({
        'type': 'call_reject',
        'call_id': callId,
        'caller_id': callerId,
      });
      return;
    }

    state = AsyncData(CallInfo(
      callId: callId,
      peerId: callerId,
      peerDisplayName: callerDisplayName,
      callType: callType == 'video' ? CallType.video : CallType.voice,
      direction: CallDirection.incoming,
      phase: CallPhase.ringing,
      sdpOffer: sdpOffer,
    ));
  }

  Future<void> handleCallAnswered({
    required String callId,
    required String sdpAnswer,
  }) async {
    _noAnswerTimer?.cancel();
    _noAnswerTimer = null;
    final current = state.valueOrNull;
    if (current == null) return;

    await ref.read(webRtcCallServiceProvider).setRemoteAnswer(sdpAnswer);
    state = AsyncData(current.copyWith(
      callId: callId,
      phase: CallPhase.connecting,
    ));
  }

  void handleCallRejected({required String callId}) {
    _noAnswerTimer?.cancel();
    _noAnswerTimer = null;
    final current = state.valueOrNull;
    if (current == null) return;

    ref.read(webRtcCallServiceProvider).dispose();
    state = const AsyncData(null);
  }

  void handleRemoteHangup({required String callId}) {
    _noAnswerTimer?.cancel();
    _noAnswerTimer = null;
    final current = state.valueOrNull;
    if (current == null) return;

    ref.read(webRtcCallServiceProvider).dispose();
    state = const AsyncData(null);
  }

  Future<void> handleIceCandidate({
    required String callId,
    required Map<String, dynamic> candidateJson,
  }) async {
    final current = state.valueOrNull;
    if (current == null) return;
    await ref.read(webRtcCallServiceProvider).addIceCandidate(candidateJson);
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  void _sendIceCandidate(RTCIceCandidate candidate, String peerId) {
    final current = state.valueOrNull;
    if (current == null) return;

    ref.read(realtimeSyncControllerProvider.notifier).sendCallSignal({
      'type': 'ice_candidate',
      'call_id': current.callId,
      'peer_id': peerId,
      'candidate': candidate.candidate,
      'sdp_mid': candidate.sdpMid,
      'sdp_mline_index': candidate.sdpMLineIndex,
    });
  }

  void _onRemoteStream(dynamic stream) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(
      phase: CallPhase.active,
      remoteStream: stream as MediaStream,
    ));
  }
}
