import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

class WebRtcCallService {
  static const List<Map<String, dynamic>> _iceServers = [
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
  ];

  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  final List<RTCIceCandidate> _pendingCandidates = [];

  void Function(RTCIceCandidate)? onIceCandidate;
  void Function(MediaStream)? onRemoteStream;
  void Function()? onConnectionFailed;

  Future<void> requestPermissions(bool withVideo) async {
    final perms = [Permission.microphone];
    if (withVideo) perms.add(Permission.camera);
    await perms.request();
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
      'iceServers': _iceServers,
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
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        onConnectionFailed?.call();
      }
    };

    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        onRemoteStream?.call(event.streams.first);
      }
    };

    return pc;
  }

  Future<({MediaStream localStream, String sdpOffer})> createOffer({
    required bool withVideo,
  }) async {
    await requestPermissions(withVideo);
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
    await requestPermissions(withVideo);
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

  Future<void> dispose() async {
    onIceCandidate = null;
    onRemoteStream = null;
    onConnectionFailed = null;
    _pendingCandidates.clear();
    _localStream?.getTracks().forEach((t) => t.stop());
    await _localStream?.dispose();
    _localStream = null;
    await _pc?.close();
    _pc = null;
  }
}
