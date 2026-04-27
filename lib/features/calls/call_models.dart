import 'package:flutter_webrtc/flutter_webrtc.dart';

enum CallType { voice, video }

enum CallDirection { outgoing, incoming }

enum CallPhase {
  idle,
  calling,
  ringing,
  connecting,
  active,
  ended,
}

class CallInfo {
  const CallInfo({
    required this.callId,
    required this.peerId,
    required this.peerDisplayName,
    required this.callType,
    required this.direction,
    required this.phase,
    this.localStream,
    this.remoteStream,
    this.isMuted = false,
    this.isCameraOff = false,
    this.sdpOffer,
  });

  final String callId;
  final String peerId;
  final String peerDisplayName;
  final CallType callType;
  final CallDirection direction;
  final CallPhase phase;
  final MediaStream? localStream;
  final MediaStream? remoteStream;
  final bool isMuted;
  final bool isCameraOff;
  final String? sdpOffer;

  CallInfo copyWith({
    String? callId,
    CallPhase? phase,
    MediaStream? localStream,
    MediaStream? remoteStream,
    bool? isMuted,
    bool? isCameraOff,
  }) {
    return CallInfo(
      callId: callId ?? this.callId,
      peerId: peerId,
      peerDisplayName: peerDisplayName,
      callType: callType,
      direction: direction,
      phase: phase ?? this.phase,
      localStream: localStream ?? this.localStream,
      remoteStream: remoteStream ?? this.remoteStream,
      isMuted: isMuted ?? this.isMuted,
      isCameraOff: isCameraOff ?? this.isCameraOff,
      sdpOffer: sdpOffer,
    );
  }
}
