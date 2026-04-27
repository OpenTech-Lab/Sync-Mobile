import 'local_chat_message.dart';

enum RealtimeConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

class RealtimeEvent {
  const RealtimeEvent._({
    this.message,
    this.connectionStatus,
    this.error,
    this.typingPartnerId,
    this.isTyping,
    this.roomMembershipChangedRoomId,
    this.incomingCallId,
    this.incomingCallCallerId,
    this.incomingCallType,
    this.incomingCallSdpOffer,
    this.answeredCallId,
    this.answeredSdpAnswer,
    this.rejectedCallId,
    this.hangupCallId,
    this.iceCandidateCallId,
    this.iceCandidateFromUserId,
    this.iceCandidate,
    this.iceSdpMid,
    this.iceSdpMlineIndex,
  });

  final LocalChatMessage? message;
  final RealtimeConnectionStatus? connectionStatus;
  final String? error;
  final String? typingPartnerId;
  final bool? isTyping;
  final String? roomMembershipChangedRoomId;

  // Call signaling fields
  final String? incomingCallId;
  final String? incomingCallCallerId;
  final String? incomingCallType;
  final String? incomingCallSdpOffer;
  final String? answeredCallId;
  final String? answeredSdpAnswer;
  final String? rejectedCallId;
  final String? hangupCallId;
  final String? iceCandidateCallId;
  final String? iceCandidateFromUserId;
  final String? iceCandidate;
  final String? iceSdpMid;
  final int? iceSdpMlineIndex;

  factory RealtimeEvent.message(LocalChatMessage message) {
    return RealtimeEvent._(message: message);
  }

  factory RealtimeEvent.connection(RealtimeConnectionStatus status) {
    return RealtimeEvent._(connectionStatus: status);
  }

  factory RealtimeEvent.error(String message) {
    return RealtimeEvent._(error: message);
  }

  factory RealtimeEvent.typing({
    required String partnerId,
    required bool isTyping,
  }) {
    return RealtimeEvent._(typingPartnerId: partnerId, isTyping: isTyping);
  }

  factory RealtimeEvent.roomMembershipChanged({required String roomId}) {
    return RealtimeEvent._(roomMembershipChangedRoomId: roomId);
  }

  factory RealtimeEvent.incomingCall({
    required String callId,
    required String callerId,
    required String callType,
    required String sdpOffer,
  }) {
    return RealtimeEvent._(
      incomingCallId: callId,
      incomingCallCallerId: callerId,
      incomingCallType: callType,
      incomingCallSdpOffer: sdpOffer,
    );
  }

  factory RealtimeEvent.callAnswered({
    required String callId,
    required String calleeId,
    required String sdpAnswer,
  }) {
    return RealtimeEvent._(
      answeredCallId: callId,
      answeredSdpAnswer: sdpAnswer,
    );
  }

  factory RealtimeEvent.callRejected({required String callId}) {
    return RealtimeEvent._(rejectedCallId: callId);
  }

  factory RealtimeEvent.callHangup({required String callId}) {
    return RealtimeEvent._(hangupCallId: callId);
  }

  factory RealtimeEvent.iceCandidate({
    required String callId,
    required String fromUserId,
    required String candidate,
    String? sdpMid,
    int? sdpMlineIndex,
  }) {
    return RealtimeEvent._(
      iceCandidateCallId: callId,
      iceCandidateFromUserId: fromUserId,
      iceCandidate: candidate,
      iceSdpMid: sdpMid,
      iceSdpMlineIndex: sdpMlineIndex,
    );
  }
}
