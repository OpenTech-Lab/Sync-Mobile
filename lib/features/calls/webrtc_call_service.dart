import 'dart:async';

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
    final config = {
      'iceServers': iceServers,
      'sdpSemantics': 'unified-plan',
    };
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

  Future<({MediaStream localStream, String sdpOffer})> createOffer({
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
    return (localStream: localStream, sdpOffer: offer.sdp ?? '');
  }

  Future<({MediaStream localStream, String sdpAnswer})> createAnswer({
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

    // Drain any ICE candidates buffered before remote description was set
    for (final c in _pendingCandidates) {
      await pc.addCandidate(c);
    }
    _pendingCandidates.clear();

    return (localStream: localStream, sdpAnswer: answer.sdp ?? '');
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

  Future<void> dispose() async {
    onIceCandidate = null;
    onRemoteStream = null;
    onConnectionConnected = null;
    onConnectionFailed = null;
    await _closeExistingCall();
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
