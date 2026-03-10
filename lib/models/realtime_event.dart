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
  });

  final LocalChatMessage? message;
  final RealtimeConnectionStatus? connectionStatus;
  final String? error;
  final String? typingPartnerId;
  final bool? isTyping;
  final String? roomMembershipChangedRoomId;

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
}
