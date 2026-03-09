class ChatTargetInput {
  const ChatTargetInput({required this.friendId, required this.serverUrl});
  final String friendId;
  final String serverUrl;
}

class CreateRoomInput {
  const CreateRoomInput({required this.name, required this.memberIds});
  final String name;
  final List<String> memberIds;
}

class RoomMemberOption {
  const RoomMemberOption({required this.userId, required this.displayName});
  final String userId;
  final String displayName;
}

class ResolvedTargetProfile {
  const ResolvedTargetProfile({
    required this.partnerId,
    required this.recipientServerUrl,
    required this.displayName,
    required this.displayHandle,
    this.avatarBase64,
    this.description,
    this.level,
    this.rank,
  });
  final String partnerId;
  final String recipientServerUrl;
  final String displayName;
  final String displayHandle;
  final String? avatarBase64;
  final String? description;
  final int? level;
  final String? rank;
}

enum ChatQuickAction { newRoom, newFriendOrChat, scanFriendQr }

enum OutgoingDeliveryState { sending, failed, blocked }

class OutgoingMessageDraft {
  const OutgoingMessageDraft({
    required this.id,
    required this.partnerId,
    required this.body,
    required this.createdAt,
    required this.state,
    this.statusLabel,
  });

  final String id;
  final String partnerId;
  final String body;
  final DateTime createdAt;
  final OutgoingDeliveryState state;
  final String? statusLabel;

  OutgoingMessageDraft copyWith({
    OutgoingDeliveryState? state,
    String? statusLabel,
    bool resetStatusLabel = false,
  }) {
    return OutgoingMessageDraft(
      id: id,
      partnerId: partnerId,
      body: body,
      createdAt: createdAt,
      state: state ?? this.state,
      statusLabel: resetStatusLabel ? null : (statusLabel ?? this.statusLabel),
    );
  }
}
