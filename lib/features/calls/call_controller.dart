import 'dart:async';
import 'dart:convert';

import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
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

/// Live microphone / incoming-audio levels for the call in progress, used by
/// the call screen's voice bars.
final callAudioLevelsProvider = StreamProvider<CallAudioLevels>(
  (ref) => ref.watch(webRtcCallServiceProvider).audioLevels,
);

class CallController extends AsyncNotifier<CallInfo?> {
  static const _pendingCallId = 'pending';

  Timer? _noAnswerTimer;
  final List<_PendingIceCandidate> _pendingIceCandidates = [];
  int _outgoingAttempt = 0;

  /// Guards [resumeCallFromPush] against re-entry. The phase check alone is
  /// racy: the offer fetch and [acceptCall] are both async, so two concurrent
  /// invocations (CallKit accept event + cold-launch catch-up) can each pass
  /// the phase check before either advances the call past `ringing`.
  String? _resumingCallId;

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
    if (state.valueOrNull != null) return;

    final attempt = ++_outgoingAttempt;
    final svc = ref.read(webRtcCallServiceProvider);
    _pendingIceCandidates.clear();

    svc.onIceCandidate = (c) => _sendIceCandidate(c, peerId);
    svc.onRemoteStream = _onRemoteStream;
    svc.onConnectionConnected = _onConnectionConnected;
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

    // ICE gathering continues in the background. The UI can open immediately,
    // while the eventual SDP still contains every gathered candidate for a
    // callee that was offline when trickle candidates were emitted.
    unawaited(
      _sendCallOfferWhenReady(
        attempt: attempt,
        peerId: peerId,
        callType: callType,
        sdpOffer: sdpOffer,
      ),
    );
  }

  // ── Incoming call — accept ─────────────────────────────────────────────────

  Future<void> acceptCall() async {
    if (!kCallingEnabled) {
      rejectCall();
      return;
    }

    final current = state.valueOrNull;
    if (current == null || current.phase != CallPhase.ringing) return;
    if (current.sdpOffer == null) {
      // No offer yet — a VoIP-push-triggered call resumes via
      // resumeCallFromPush(), which fetches the stashed offer and re-enters
      // this method once it has one.
      return;
    }

    final svc = ref.read(webRtcCallServiceProvider);

    svc.onIceCandidate = (c) => _sendIceCandidate(c, current.peerId);
    svc.onRemoteStream = _onRemoteStream;
    svc.onConnectionConnected = _onConnectionConnected;
    svc.onConnectionFailed = hangup;

    await _applyIceServers(svc);

    final (:localStream, :sdpAnswer) = await svc.createAnswer(
      sdpOffer: current.sdpOffer!,
      withVideo: current.callType == CallType.video,
    );

    // Re-read state after the async gap: the peer connection may already have
    // reached Connected and advanced the phase to active.
    final latest = state.valueOrNull ?? current;
    state = AsyncData(
      latest.copyWith(
        localStream: localStream,
        phase: latest.phase == CallPhase.active ? CallPhase.active : CallPhase.connecting,
      ),
    );

    unawaited(
      _sendCallAnswerWhenReady(
        callId: current.callId,
        callerId: current.peerId,
        sdpAnswer: sdpAnswer,
      ),
    );
  }

  /// Resumes a call that was surfaced via a CallKit/PushKit incoming push
  /// rather than the WebSocket `incoming_call` signal. The push payload
  /// carries no SDP (PushKit payloads are small and time-sensitive), so this
  /// fetches the stashed offer the server held for us, then proceeds through
  /// the normal [acceptCall] path.
  Future<void> resumeCallFromPush({
    required String callId,
    required String callerId,
    required String callerDisplayName,
    required String callType,
  }) async {
    if (!kCallingEnabled) {
      await _reportCallKitEnded(callId);
      return;
    }

    final current = state.valueOrNull;
    if (current != null && current.callId != callId) {
      // Already in a different call — nothing sensible to resume into.
      await _reportCallKitEnded(callId);
      return;
    }
    if (_resumingCallId == callId) return;
    if (current != null && current.phase != CallPhase.ringing) {
      // Already accepted (connecting/active) or tearing down. This method can
      // legitimately be entered twice for one call — once from the CallKit
      // accept event and once from CallkitService's cold-launch catch-up — and
      // resuming a second time would answer the same call twice.
      return;
    }
    _resumingCallId = callId;
    try {
      if (current == null) {
        // Not yet tracked locally (e.g. app was terminated and CallKit is the
        // only thing that knows about this call so far).
        state = AsyncData(
          CallInfo(
            callId: callId,
            peerId: callerId,
            peerDisplayName: callerDisplayName,
            callType: callType == 'video' ? CallType.video : CallType.voice,
            direction: CallDirection.incoming,
            phase: CallPhase.ringing,
          ),
        );
      }

      // Prefer an offer we already hold from the WebSocket `incoming_call`
      // signal. The server's stash is single-use (Redis GETDEL), so fetching
      // it when we can already answer both wastes the one read and, if this
      // method runs twice for the same call, makes the second run see a 404
      // and reject a call that is already connecting.
      final offer =
          state.valueOrNull?.sdpOffer ?? await _fetchStashedOffer(callId);
      if (offer == null) {
        // Offer already claimed/expired/not found — nothing to answer with.
        rejectCall();
        return;
      }

      final latest = state.valueOrNull;
      if (latest == null || latest.callId != callId) return;
      state = AsyncData(latest.copyWith(sdpOffer: offer));

      await acceptCall();
    } finally {
      if (_resumingCallId == callId) _resumingCallId = null;
    }
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

    ref.read(webRtcCallServiceProvider).endCall();
    _outgoingAttempt += 1;
    _pendingIceCandidates.clear();
    unawaited(_reportCallKitEnded(current.callId));
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

    ref.read(webRtcCallServiceProvider).endCall();
    _outgoingAttempt += 1;
    _pendingIceCandidates.clear();
    unawaited(_reportCallKitEnded(current.callId));
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

  void toggleSpeaker() {
    final current = state.valueOrNull;
    if (current == null) return;
    final next = !current.isSpeakerOn;
    ref.read(webRtcCallServiceProvider).setSpeaker(next);
    state = AsyncData(current.copyWith(isSpeakerOn: next));
  }

  // ── Inbound signaling handlers ─────────────────────────────────────────────

  void handleIncomingCall({
    required String callId,
    required String callerId,
    required String callerDisplayName,
    required String callType,
    String? sdpOffer,
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
    if (current != null) {
      // A foregrounded app can receive both the WS `incoming_call` signal and
      // the VoIP push for the same call. If we're already tracking this exact
      // call (e.g. resumeCallFromPush already created it), just fill in the
      // offer if this event is the one carrying it — don't reject our own call.
      if (current.callId == callId) {
        if (sdpOffer != null && current.sdpOffer == null) {
          state = AsyncData(current.copyWith(sdpOffer: sdpOffer));
        }
        return;
      }
      // Auto-reject if already in a different call.
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
    if (current.callId != callId) return;

    await ref.read(webRtcCallServiceProvider).setRemoteAnswer(sdpAnswer);

    // Re-read state after the async gap: the peer connection may already have
    // reached Connected and advanced the phase to active.
    final latest = state.valueOrNull;
    if (latest == null) return;
    if (latest.phase != CallPhase.active) {
      state = AsyncData(latest.copyWith(callId: callId, phase: CallPhase.connecting));
    }
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
    if (current.callId != callId) return;

    ref.read(webRtcCallServiceProvider).endCall();
    _pendingIceCandidates.clear();
    unawaited(_reportCallKitEnded(callId));
    state = const AsyncData(null);
  }

  void handleRemoteHangup({required String callId}) {
    _noAnswerTimer?.cancel();
    _noAnswerTimer = null;
    final current = state.valueOrNull;
    if (current == null) return;
    if (current.callId != callId) return;

    ref.read(webRtcCallServiceProvider).endCall();
    _pendingIceCandidates.clear();
    unawaited(_reportCallKitEnded(callId));
    state = const AsyncData(null);
  }

  Future<void> handleIceCandidate({
    required String callId,
    required Map<String, dynamic> candidateJson,
  }) async {
    final current = state.valueOrNull;
    if (current == null) return;
    if (current.callId != callId) return;
    await ref.read(webRtcCallServiceProvider).addIceCandidate(candidateJson);
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  Future<void> _sendCallOfferWhenReady({
    required int attempt,
    required String peerId,
    required CallType callType,
    required Future<String> sdpOffer,
  }) async {
    final offer = await sdpOffer;
    final current = state.valueOrNull;
    if (attempt != _outgoingAttempt ||
        current == null ||
        current.callId != _pendingCallId ||
        current.peerId != peerId) {
      return;
    }

    ref.read(realtimeSyncControllerProvider.notifier).sendCallSignal({
      'type': 'call_offer',
      'callee_id': peerId,
      'call_type': callType == CallType.voice ? 'voice' : 'video',
      'sdp_offer': offer,
    });

    // Start the no-answer clock when the callee is actually signaled, not
    // while local ICE gathering is still in progress.
    _noAnswerTimer?.cancel();
    _noAnswerTimer = Timer(const Duration(seconds: 45), () {
      final latest = state.valueOrNull;
      if (latest != null && latest.phase == CallPhase.calling) {
        hangup();
      }
    });
  }

  Future<void> _sendCallAnswerWhenReady({
    required String callId,
    required String callerId,
    required Future<String> sdpAnswer,
  }) async {
    final answer = await sdpAnswer;
    final current = state.valueOrNull;
    if (current == null || current.callId != callId) return;

    ref.read(realtimeSyncControllerProvider.notifier).sendCallSignal({
      'type': 'call_answer',
      'call_id': callId,
      'caller_id': callerId,
      'sdp_answer': answer,
    });
  }

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

  /// Fetches the SDP offer the server stashed for [callId] (see
  /// `GET /api/calls/offer/{call_id}`), for calls resumed from a VoIP push.
  /// Uses the same authed-HTTP-GET pattern as [_applyIceServers]. Returns
  /// null on any error (missing auth, network failure, 404 because the
  /// offer was already claimed/expired) — callers should treat that as
  /// "nothing to answer with".
  Future<String?> _fetchStashedOffer(String callId) async {
    final ctrl = ref.read(realtimeSyncControllerProvider.notifier);
    final baseUrl = ctrl.baseUrl;
    final tokenFn = ctrl.accessTokenProvider;
    if (baseUrl == null || tokenFn == null) return null;
    final token = await tokenFn();
    if (token == null || token.isEmpty) return null;
    try {
      final uri = Uri.parse('$baseUrl/api/calls/offer/$callId');
      final response = await http
          .get(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final offer = body['sdp_offer'] as String?;
        if (offer != null && offer.isNotEmpty) return offer;
      }
    } catch (_) {
      // Non-fatal: treated as "no offer available" by the caller.
    }
    return null;
  }

  /// Tells CallKit the call is now connected so the native call UI reflects
  /// the Dart side's state instead of lingering on "connecting" forever.
  Future<void> _reportCallKitConnected(String callId) async {
    try {
      await FlutterCallkitIncoming.setCallConnected(callId);
    } catch (_) {
      // CallKit is iOS-only / best-effort; ignore on platforms or in states
      // where there's no matching native call to update.
    }
  }

  /// Tells CallKit the call has ended so the native call UI is dismissed
  /// after the Dart side resolves the call (reject/hangup/remote-hangup).
  Future<void> _reportCallKitEnded(String callId) async {
    try {
      await FlutterCallkitIncoming.endCall(callId);
    } catch (_) {
      // Same as above — best-effort, safe to ignore.
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
    state = AsyncData(current.copyWith(remoteStream: stream as MediaStream));
  }

  void _onConnectionConnected() {
    final current = state.valueOrNull;
    if (current == null || current.callId == _pendingCallId) return;
    state = AsyncData(current.copyWith(phase: CallPhase.active));
    // This is intentionally driven by the peer connection, not by sending
    // the SDP answer. Calling setCallConnected earlier can make
    // flutter_callkit_incoming issue a second answer transaction while ICE is
    // still negotiating.
    unawaited(_reportCallKitConnected(current.callId));
  }
}

class _PendingIceCandidate {
  const _PendingIceCandidate({required this.candidate, required this.peerId});

  final RTCIceCandidate candidate;
  final String peerId;
}
