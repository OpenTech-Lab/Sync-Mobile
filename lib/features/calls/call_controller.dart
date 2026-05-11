import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;

import '../../constants/feature_flags.dart';
import '../../state/realtime_sync_controller.dart';
import 'call_models.dart';
import 'webrtc_call_service.dart';

final webRtcCallServiceProvider = Provider<WebRtcCallService>((ref) {
  final svc = WebRtcCallService();
  ref.onDispose(svc.dispose);
  return svc;
});

final callControllerProvider = AsyncNotifierProvider<CallController, CallInfo?>(
  CallController.new,
);

class CallController extends AsyncNotifier<CallInfo?> {
  static const _pendingCallId = 'pending';

  Timer? _noAnswerTimer;
  final List<_PendingIceCandidate> _pendingIceCandidates = [];

  @override
  Future<CallInfo?> build() async => null;

  // ── Outgoing call ──────────────────────────────────────────────────────────

  Future<void> startCall({
    required String peerId,
    required String peerDisplayName,
    required CallType callType,
  }) async {
    if (!kCallingEnabled) {
      return;
    }

    final svc = ref.read(webRtcCallServiceProvider);
    _pendingIceCandidates.clear();

    svc.onIceCandidate = (c) => _sendIceCandidate(c, peerId);
    svc.onRemoteStream = _onRemoteStream;
    svc.onConnectionFailed = hangup;

    await _applyIceServers(svc);

    final (:localStream, :sdpOffer) = await svc.createOffer(
      withVideo: callType == CallType.video,
    );

    // The server creates the durable call record after this offer is sent.
    // Queue ICE until its call_created ack gives us the real UUID.
    state = AsyncData(
      CallInfo(
        callId: _pendingCallId,
        peerId: peerId,
        peerDisplayName: peerDisplayName,
        callType: callType,
        direction: CallDirection.outgoing,
        phase: CallPhase.calling,
        localStream: localStream,
      ),
    );

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
    if (!kCallingEnabled) {
      rejectCall();
      return;
    }

    final current = state.valueOrNull;
    if (current == null || current.phase != CallPhase.ringing) return;

    final svc = ref.read(webRtcCallServiceProvider);

    svc.onIceCandidate = (c) => _sendIceCandidate(c, current.peerId);
    svc.onRemoteStream = _onRemoteStream;
    svc.onConnectionFailed = hangup;

    await _applyIceServers(svc);

    final (:localStream, :sdpAnswer) = await svc.createAnswer(
      sdpOffer: current.sdpOffer!,
      withVideo: current.callType == CallType.video,
    );

    state = AsyncData(
      current.copyWith(phase: CallPhase.connecting, localStream: localStream),
    );

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
    _pendingIceCandidates.clear();
    state = const AsyncData(null);
  }

  // ── Hang up ────────────────────────────────────────────────────────────────

  void hangup() {
    _noAnswerTimer?.cancel();
    _noAnswerTimer = null;
    final current = state.valueOrNull;
    if (current == null) return;

    if (current.callId != _pendingCallId) {
      ref.read(realtimeSyncControllerProvider.notifier).sendCallSignal({
        'type': 'call_hangup',
        'call_id': current.callId,
        'peer_id': current.peerId,
      });
    }

    ref.read(webRtcCallServiceProvider).dispose();
    _pendingIceCandidates.clear();
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
    if (!kCallingEnabled) {
      ref.read(realtimeSyncControllerProvider.notifier).sendCallSignal({
        'type': 'call_reject',
        'call_id': callId,
        'caller_id': callerId,
      });
      return;
    }

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

    state = AsyncData(
      CallInfo(
        callId: callId,
        peerId: callerId,
        peerDisplayName: callerDisplayName,
        callType: callType == 'video' ? CallType.video : CallType.voice,
        direction: CallDirection.incoming,
        phase: CallPhase.ringing,
        sdpOffer: sdpOffer,
      ),
    );
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
    state = AsyncData(
      current.copyWith(callId: callId, phase: CallPhase.connecting),
    );
    _flushPendingIceCandidates();
  }

  void handleCallCreated({required String callId}) {
    final current = state.valueOrNull;
    if (current == null || current.direction != CallDirection.outgoing) {
      return;
    }
    state = AsyncData(current.copyWith(callId: callId));
    _flushPendingIceCandidates();
  }

  void handleCallRejected({required String callId}) {
    _noAnswerTimer?.cancel();
    _noAnswerTimer = null;
    final current = state.valueOrNull;
    if (current == null) return;

    ref.read(webRtcCallServiceProvider).dispose();
    _pendingIceCandidates.clear();
    state = const AsyncData(null);
  }

  void handleRemoteHangup({required String callId}) {
    _noAnswerTimer?.cancel();
    _noAnswerTimer = null;
    final current = state.valueOrNull;
    if (current == null) return;

    ref.read(webRtcCallServiceProvider).dispose();
    _pendingIceCandidates.clear();
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

  /// Fetches ICE server config from the API and applies it to [svc].
  /// Falls back to STUN-only on any error so calls still work without TURN.
  Future<void> _applyIceServers(WebRtcCallService svc) async {
    final ctrl = ref.read(realtimeSyncControllerProvider.notifier);
    final baseUrl = ctrl.baseUrl;
    final tokenFn = ctrl.accessTokenProvider;
    if (baseUrl == null || tokenFn == null) return;
    final token = await tokenFn();
    if (token == null || token.isEmpty) return;
    try {
      final uri = Uri.parse('$baseUrl/api/calls/ice-servers');
      final response = await http
          .get(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final servers = (body['ice_servers'] as List)
            .cast<Map<String, dynamic>>();
        if (servers.isNotEmpty) {
          svc.iceServers = servers;
        }
      }
    } catch (_) {
      // Non-fatal: fall back to the default STUN-only config already set.
    }
  }

  void _sendIceCandidate(RTCIceCandidate candidate, String peerId) {
    final current = state.valueOrNull;
    if (current == null || current.callId == _pendingCallId) {
      _pendingIceCandidates.add(
        _PendingIceCandidate(candidate: candidate, peerId: peerId),
      );
      return;
    }

    _sendIceCandidatePayload(
      callId: current.callId,
      peerId: peerId,
      candidate: candidate,
    );
  }

  void _flushPendingIceCandidates() {
    final current = state.valueOrNull;
    if (current == null || current.callId == _pendingCallId) {
      return;
    }
    final pending = List<_PendingIceCandidate>.of(_pendingIceCandidates);
    _pendingIceCandidates.clear();
    for (final item in pending) {
      _sendIceCandidatePayload(
        callId: current.callId,
        peerId: item.peerId,
        candidate: item.candidate,
      );
    }
  }

  void _sendIceCandidatePayload({
    required String callId,
    required String peerId,
    required RTCIceCandidate candidate,
  }) {
    ref.read(realtimeSyncControllerProvider.notifier).sendCallSignal({
      'type': 'ice_candidate',
      'call_id': callId,
      'peer_id': peerId,
      'candidate': candidate.candidate,
      'sdp_mid': candidate.sdpMid,
      'sdp_mline_index': candidate.sdpMLineIndex,
    });
  }

  void _onRemoteStream(dynamic stream) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        phase: CallPhase.active,
        remoteStream: stream as MediaStream,
      ),
    );
  }
}

class _PendingIceCandidate {
  const _PendingIceCandidate({required this.candidate, required this.peerId});

  final RTCIceCandidate candidate;
  final String peerId;
}
