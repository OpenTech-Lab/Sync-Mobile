import 'local_chat_message.dart';

enum RealtimeConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

class RealtimeEvent {
  const RealtimeEvent._({this.message, this.connectionStatus, this.error});

  final LocalChatMessage? message;
  final RealtimeConnectionStatus? connectionStatus;
  final String? error;

  factory RealtimeEvent.message(LocalChatMessage message) {
    return RealtimeEvent._(message: message);
  }

  factory RealtimeEvent.connection(RealtimeConnectionStatus status) {
    return RealtimeEvent._(connectionStatus: status);
  }

  factory RealtimeEvent.error(String message) {
    return RealtimeEvent._(error: message);
  }
}
