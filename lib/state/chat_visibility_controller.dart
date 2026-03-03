import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChatVisibilityState {
  const ChatVisibilityState({
    required this.isChatsTabSelected,
    required this.activePartnerId,
  });

  final bool isChatsTabSelected;
  final String? activePartnerId;

  bool isConversationOpen(String partnerId) {
    return isChatsTabSelected && activePartnerId == partnerId;
  }

  ChatVisibilityState copyWith({
    bool? isChatsTabSelected,
    String? activePartnerId,
    bool clearActivePartnerId = false,
  }) {
    return ChatVisibilityState(
      isChatsTabSelected: isChatsTabSelected ?? this.isChatsTabSelected,
      activePartnerId: clearActivePartnerId
          ? null
          : activePartnerId ?? this.activePartnerId,
    );
  }
}

final chatVisibilityProvider = StateProvider<ChatVisibilityState>(
  (_) => const ChatVisibilityState(
    isChatsTabSelected: false,
    activePartnerId: null,
  ),
);
