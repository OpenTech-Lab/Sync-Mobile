import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

/// A sample of how loud each side of the call currently is, taken from the
/// peer connection's own stats.
///
/// [local] is the microphone's level and [remote] the level of the decoded
/// incoming track, both 0..1. [remoteBytes] is the running total of audio
/// bytes received, which distinguishes "no media is arriving" from "media is
/// arriving but is silent".
class CallAudioLevels {
  const CallAudioLevels({
    this.local = 0,
    this.remote = 0,
    this.remoteBytes = 0,
  });

  final double local;
  final double remote;
  final int remoteBytes;
}

/// Thrown by [WebRtcCallService.createOffer]/[WebRtcCallService.createAnswer]
/// when the user denies microphone (or camera, for video calls) permission.
class CallPermissionDeniedException implements Exception {
  const CallPermissionDeniedException();

  @override
  String toString() => 'CallPermissionDeniedException: microphone/camera permission denied';
}

class WebRtcCallService {
  static const _iceGatheringTimeout = Duration(seconds: 8);

  /// ICE servers used for the next peer connection. Set this before calling
  /// [createOffer] or [createAnswer]. Defaults to Google's public STUN servers
  /// so calls still work if the server has no TURN configured.
  List<Map<String, dynamic>> iceServers = const [
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
  ];

  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  final List<RTCIceCandidate> _pendingCandidates = [];

  void Function(RTCIceCandidate)? onIceCandidate;
  void Function(MediaStream)? onRemoteStream;
  void Function()? onConnectionConnected;
  void Function()? onConnectionFailed;

  Timer? _audioLevelTimer;
  final _audioLevels = StreamController<CallAudioLevels>.broadcast();

  /// Periodic microphone / incoming-track loudness while a call is up.
  /// Emits nothing once the peer connection is closed.
  Stream<CallAudioLevels> get audioLevels => _audioLevels.stream;

  void _startAudioLevelPolling() {
    _audioLevelTimer?.cancel();
    _audioLevelTimer = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) async {
        final pc = _pc;
        if (pc == null || _audioLevels.isClosed) return;
        try {
          var local = 0.0;
          var remote = 0.0;
          var remoteBytes = 0;
          for (final report in await pc.getStats()) {
            final values = report.values;
            if (values['kind'] != 'audio') continue;
            final level = values['audioLevel'];
            // `media-source` is our own microphone; `inbound-rtp` is the
            // decoded stream coming from the peer.
            if (report.type == 'media-source' && level is num) {
              local = level.toDouble();
            } else if (report.type == 'inbound-rtp') {
              if (level is num) remote = level.toDouble();
              final bytes = values['bytesReceived'];
              if (bytes is num) remoteBytes = bytes.toInt();
            }
          }
          if (_audioLevels.isClosed) return;
          _audioLevels.add(
            CallAudioLevels(
              local: local,
              remote: remote,
              remoteBytes: remoteBytes,
            ),
          );
        } catch (_) {
          // Stats are best-effort diagnostics; never disturb the call.
        }
      },
    );
  }

  /// Requests microphone (and, if [withVideo], camera) permission.
  /// Returns whether every requested permission was granted.
  Future<bool> requestPermissions(bool withVideo) async {
    final perms = [Permission.microphone];
    if (withVideo) perms.add(Permission.camera);
    final statuses = await perms.request();
    return statuses.values.every((status) => status.isGranted);
  }

  Future<MediaStream> _openLocalStream(bool withVideo) async {
    final constraints = <String, dynamic>{
      'audio': true,
      'video': withVideo
          ? {'facingMode': 'user', 'width': 640, 'height': 480}
          : false,
    };
    _localStream = await navigator.mediaDevices.getUserMedia(constraints);
    return _localStream!;
  }

  Future<RTCPeerConnection> _createPeerConnection() async {
    final config = peerConnectionConfigurationForTest();
    final pc = await createPeerConnection(config);
    _pc = pc;

    pc.onIceCandidate = (candidate) {
      if (candidate.candidate != null && candidate.candidate!.isNotEmpty) {
        onIceCandidate?.call(candidate);
      }
    };

    pc.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        onConnectionConnected?.call();
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        onConnectionFailed?.call();
      }
    };

    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        onRemoteStream?.call(event.streams.first);
      }
    };

    _startAudioLevelPolling();

    return pc;
  }

  /// Builds the configuration used for each peer connection.
  ///
  /// Mobile carrier and same-NAT host/server-reflexive paths were unreliable
  /// in production even though TURN was healthy. Once the API provides TURN,
  /// use it as the deterministic media path. STUN-only remains available as a
  /// fallback when the TURN configuration endpoint cannot be reached.
  @visibleForTesting
  Map<String, dynamic> peerConnectionConfigurationForTest() {
    final hasTurn = iceServers.any((server) {
      final urls = server['urls'];
      if (urls is String) {
        return urls.startsWith('turn:') || urls.startsWith('turns:');
      }
      if (urls is Iterable) {
        return urls.whereType<String>().any(
          (url) => url.startsWith('turn:') || url.startsWith('turns:'),
        );
      }
      return false;
    });
    return {
      'iceServers': iceServers,
      'iceTransportPolicy': hasTurn ? 'relay' : 'all',
      'sdpSemantics': 'unified-plan',
    };
  }

  Future<({MediaStream localStream, Future<String> sdpOffer})> createOffer({
    required bool withVideo,
  }) async {
    // Guard against leaking a previous call's peer connection/tracks if a
    // new call is started before the last one was properly disposed.
    await _closeExistingCall();
    if (!await requestPermissions(withVideo)) {
      throw const CallPermissionDeniedException();
    }
    final localStream = await _openLocalStream(withVideo);
    final pc = await _createPeerConnection();

    for (final track in localStream.getTracks()) {
      await pc.addTrack(track, localStream);
    }

    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    final gatheredOffer = _localDescriptionAfterIceGathering(
      pc,
      fallback: offer,
    ).then((description) => description.sdp ?? '');
    return (localStream: localStream, sdpOffer: gatheredOffer);
  }

  Future<({MediaStream localStream, Future<String> sdpAnswer})> createAnswer({
    required String sdpOffer,
    required bool withVideo,
  }) async {
    if (!await requestPermissions(withVideo)) {
      throw const CallPermissionDeniedException();
    }
    final localStream = await _openLocalStream(withVideo);
    final pc = await _createPeerConnection();

    for (final track in localStream.getTracks()) {
      await pc.addTrack(track, localStream);
    }

    await pc.setRemoteDescription(RTCSessionDescription(sdpOffer, 'offer'));
    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);
    final gatheredAnswer = _localDescriptionAfterIceGathering(
      pc,
      fallback: answer,
    ).then((description) => description.sdp ?? '');

    // Drain any ICE candidates buffered before remote description was set
    for (final c in _pendingCandidates) {
      await pc.addCandidate(c);
    }
    _pendingCandidates.clear();

    return (localStream: localStream, sdpAnswer: gatheredAnswer);
  }

  /// Returns the current local SDP after ICE gathering has completed, so the
  /// SDP itself contains usable host/STUN/TURN candidates.
  ///
  /// We still trickle candidates through the WebSocket for fast foreground
  /// calls. The self-contained SDP is required for a cold incoming call,
  /// though: while the callee is offline, Redis pub/sub cannot retain the
  /// caller's trickled candidates, whereas the server does retain the offer.
  /// A timeout keeps a slow or unavailable ICE server from blocking the call;
  /// in that case the best local description gathered so far is returned.
  Future<RTCSessionDescription> _localDescriptionAfterIceGathering(
    RTCPeerConnection pc, {
    required RTCSessionDescription fallback,
  }) async {
    const complete = RTCIceGatheringState.RTCIceGatheringStateComplete;
    try {
      if (await pc.getIceGatheringState() != complete) {
        final completer = Completer<void>();
        pc.onIceGatheringState = (state) {
          if (state == complete && !completer.isCompleted) {
            completer.complete();
          }
        };
        try {
          // Close the race where gathering completed between the first state
          // check and installing the callback.
          if (await pc.getIceGatheringState() != complete) {
            await completer.future.timeout(_iceGatheringTimeout);
          }
        } on TimeoutException {
          // Use the candidates gathered so far; trickle ICE remains active.
        } finally {
          pc.onIceGatheringState = null;
        }
      }
      return await pc.getLocalDescription() ?? fallback;
    } catch (_) {
      // A platform state query must not prevent signaling. The initial local
      // description is still valid and trickle ICE remains available.
      pc.onIceGatheringState = null;
      return fallback;
    }
  }

  Future<void> setRemoteAnswer(String sdpAnswer) async {
    final pc = _pc;
    if (pc == null) return;
    await pc.setRemoteDescription(RTCSessionDescription(sdpAnswer, 'answer'));

    // Drain buffered ICE candidates
    for (final c in _pendingCandidates) {
      await pc.addCandidate(c);
    }
    _pendingCandidates.clear();
  }

  Future<void> addIceCandidate(Map<String, dynamic> candidateJson) async {
    final candidate = RTCIceCandidate(
      candidateJson['candidate'] as String? ?? '',
      candidateJson['sdpMid'] as String?,
      candidateJson['sdpMLineIndex'] as int?,
    );

    final pc = _pc;
    if (pc == null ||
        (await pc.getRemoteDescription()) == null) {
      // Buffer until remote description is set
      _pendingCandidates.add(candidate);
      return;
    }
    await pc.addCandidate(candidate);
  }

  void setMuted(bool muted) {
    _localStream?.getAudioTracks().forEach((t) => t.enabled = !muted);
  }

  void setCameraEnabled(bool enabled) {
    _localStream?.getVideoTracks().forEach((t) => t.enabled = enabled);
  }

  void setSpeaker(bool on) {
    Helper.setSpeakerphoneOn(on);
  }

  /// Ends the current call while keeping this provider-owned service reusable
  /// for the next call.
  Future<void> endCall() async {
    onIceCandidate = null;
    onRemoteStream = null;
    onConnectionConnected = null;
    onConnectionFailed = null;
    await _closeExistingCall();
  }

  Future<void> dispose() async {
    await endCall();
    await _audioLevels.close();
  }

  /// Stops and releases the current peer connection and local media tracks,
  /// if any. Unlike [dispose], this leaves the callback fields alone so it
  /// is safe to call at the start of [createOffer] right after the caller
  /// has just wired up callbacks for the new call.
  Future<void> _closeExistingCall() async {
    _audioLevelTimer?.cancel();
    _audioLevelTimer = null;
    _pendingCandidates.clear();
    _localStream?.getTracks().forEach((t) => t.stop());
    await _localStream?.dispose();
    _localStream = null;
    await _pc?.close();
    _pc = null;
  }
}
