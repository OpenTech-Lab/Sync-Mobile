import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_controller.dart';
import '../models/chat_room.dart';
import '../models/local_chat_message.dart';
import '../services/backup_preferences.dart';
import '../services/local_chat_repository.dart';
import '../services/message_e2ee_service.dart';
import '../services/remote_chat_service.dart';
import '../services/remote_user_profile_service.dart';
import 'hidden_conversation_ids_controller.dart';
import 'user_profile_controller.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final serverUrl = ref.watch(activeServerUrlProvider);
  final supportsEncryptedLocalDb =
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  // sqflite_sqlcipher is not available on web/linux/windows.
  return supportsEncryptedLocalDb && serverUrl != null
      ? LocalChatRepository(serverUrl: serverUrl)
      : InMemoryChatRepository();
});

final remoteChatServiceProvider = Provider<RemoteChatService>((ref) {
  return RemoteChatService();
});

final messageE2eeServiceProvider = Provider<MessageE2eeService>((ref) {
  return MessageE2eeService();
});

final conversationSummariesProvider = FutureProvider<List<ConversationSummary>>(
  (ref) {
    // Use ref.watch so this provider rebuilds whenever the active server
    // (and therefore the chat repository) changes.
    final repository = ref.watch(chatRepositoryProvider);
    return repository.listConversations();
  },
);

final roomConversationsProvider =
    AsyncNotifierProvider<RoomConversationsController, List<ChatRoom>>(
      RoomConversationsController.new,
    );

final conversationMessagesProvider =
    AsyncNotifierProviderFamily<
      ConversationMessagesController,
      List<LocalChatMessage>,
      String
    >(ConversationMessagesController.new);

class RoomConversationsController extends AsyncNotifier<List<ChatRoom>> {
  ChatRepository get _repository => ref.read(chatRepositoryProvider);
  RemoteChatService get _remoteChatService =>
      ref.read(remoteChatServiceProvider);

  @override
  Future<List<ChatRoom>> build() {
    ref.watch(chatRepositoryProvider);
    return _repository.listRooms();
  }

  Future<List<ChatRoom>> syncRooms({
    required String baseUrl,
    required String accessToken,
  }) async {
    final rooms = await _remoteChatService.listRooms(
      baseUrl: baseUrl,
      accessToken: accessToken,
    );
    await _repository.replaceRooms(rooms);
    ref.invalidate(conversationSummariesProvider);
    state = AsyncData(await _repository.listRooms());
    return rooms;
  }

  Future<ChatRoom> createRoom({
    required String baseUrl,
    required String accessToken,
    required String name,
    required List<String> memberIds,
  }) async {
    final room = await _remoteChatService.createRoom(
      baseUrl: baseUrl,
      accessToken: accessToken,
      name: name,
      memberIds: memberIds,
    );
    await syncRooms(baseUrl: baseUrl, accessToken: accessToken);
    return room;
  }

  Future<void> markRoomReadLocal(String roomId) async {
    await _repository.updateRoomUnreadCount(roomId: roomId, unreadCount: 0);
    ref.invalidate(conversationSummariesProvider);
    state = AsyncData(await _repository.listRooms());
  }

  Future<void> leaveRoom({
    required String baseUrl,
    required String accessToken,
    required String roomId,
  }) async {
    await _remoteChatService.leaveRoom(
      baseUrl: baseUrl,
      accessToken: accessToken,
      roomId: roomId,
    );
    await syncRooms(baseUrl: baseUrl, accessToken: accessToken);
  }

  Future<RoomDetail> inviteMembers({
    required String baseUrl,
    required String accessToken,
    required String roomId,
    required List<String> memberIds,
  }) async {
    final detail = await _remoteChatService.addRoomMembers(
      baseUrl: baseUrl,
      accessToken: accessToken,
      roomId: roomId,
      memberIds: memberIds,
    );
    await syncRooms(baseUrl: baseUrl, accessToken: accessToken);
    return detail;
  }

  Future<RoomDetail> removeMember({
    required String baseUrl,
    required String accessToken,
    required String roomId,
    required String memberId,
  }) async {
    final detail = await _remoteChatService.removeRoomMember(
      baseUrl: baseUrl,
      accessToken: accessToken,
      roomId: roomId,
      memberId: memberId,
    );
    await syncRooms(baseUrl: baseUrl, accessToken: accessToken);
    return detail;
  }

  Future<void> deleteRoom({
    required String baseUrl,
    required String accessToken,
    required String roomId,
  }) async {
    await _remoteChatService.deleteRoom(
      baseUrl: baseUrl,
      accessToken: accessToken,
      roomId: roomId,
    );
    await syncRooms(baseUrl: baseUrl, accessToken: accessToken);
  }
}

class ConversationMessagesController
    extends FamilyAsyncNotifier<List<LocalChatMessage>, String> {
  static const _recipientKeyCacheTtl = Duration(minutes: 5);

  ChatRepository get _repository => ref.read(chatRepositoryProvider);
  RemoteChatService get _remoteChatService =>
      ref.read(remoteChatServiceProvider);
  RemoteUserProfileService get _profileService =>
      ref.read(remoteUserProfileServiceProvider);
  MessageE2eeService get _e2eeService => ref.read(messageE2eeServiceProvider);
  String? _cachedRecipientPublicKey;
  DateTime? _cachedRecipientPublicKeyAt;

  @override
  Future<List<LocalChatMessage>> build(String partnerId) {
    // Watch chatRepositoryProvider so this notifier rebuilds (and clears its
    // cached messages) whenever the active server URL changes.
    ref.watch(chatRepositoryProvider);
    return _repository.listMessages(conversationId: partnerId, limit: 200);
  }

  bool get _isRoomConversation => isRoomConversationId(arg);
  String get _roomId => tryParseRoomId(arg)!;

  Future<DateTime?> _latestClearedAt(String baseUrl) async {
    final preferences = BackupPreferences();
    final globalClearedAt = await preferences.readChatClearedAt(baseUrl);
    final conversationClearedAt = await preferences.readConversationClearedAt(
      baseUrl,
      arg,
    );
    if (globalClearedAt == null) {
      return conversationClearedAt;
    }
    if (conversationClearedAt == null) {
      return globalClearedAt;
    }
    return globalClearedAt.isAfter(conversationClearedAt)
        ? globalClearedAt
        : conversationClearedAt;
  }

  Future<void> _unhideConversationIfNeeded() async {
    if (_isRoomConversation) {
      return;
    }
    await ref.read(hiddenConversationIdsProvider.notifier).unhide(arg);
  }

  Future<void> syncLatest({
    required String baseUrl,
    required String accessToken,
    required String currentUserId,
  }) async {
    final latest = _isRoomConversation
        ? await _remoteChatService.getRoomMessages(
            baseUrl: baseUrl,
            accessToken: accessToken,
            roomId: _roomId,
            limit: 30,
          )
        : await _remoteChatService.getConversation(
            baseUrl: baseUrl,
            accessToken: accessToken,
            currentUserId: currentUserId,
            partnerId: arg,
            limit: 30,
          );

    // Don't restore messages that pre-date a local-data deletion.
    final clearedAt = await _latestClearedAt(baseUrl);
    final toUpsert = clearedAt == null
        ? latest
        : latest.where((m) => m.createdAt.isAfter(clearedAt)).toList();

    await _repository.upsertMessages(toUpsert);
    if (toUpsert.isNotEmpty) {
      await _unhideConversationIfNeeded();
    }
    if (_isRoomConversation) {
      await ref
          .read(roomConversationsProvider.notifier)
          .markRoomReadLocal(_roomId);
    } else {
      ref.invalidate(conversationSummariesProvider);
    }
    final local = await _repository.listMessages(
      conversationId: arg,
      limit: 200,
    );
    state = AsyncData(local);
  }

  Future<void> loadMore({
    required String baseUrl,
    required String accessToken,
    required String currentUserId,
  }) async {
    final current = state.value ?? [];
    if (current.isEmpty) {
      await syncLatest(
        baseUrl: baseUrl,
        accessToken: accessToken,
        currentUserId: currentUserId,
      );
      return;
    }

    final before = current.last.id;
    final clearedAt = await _latestClearedAt(baseUrl);
    final older = _isRoomConversation
        ? await _remoteChatService.getRoomMessages(
            baseUrl: baseUrl,
            accessToken: accessToken,
            roomId: _roomId,
            before: before,
            limit: 30,
          )
        : await _remoteChatService.getConversation(
            baseUrl: baseUrl,
            accessToken: accessToken,
            currentUserId: currentUserId,
            partnerId: arg,
            before: before,
            limit: 30,
          );

    final toUpsert = clearedAt == null
        ? older
        : older.where((m) => m.createdAt.isAfter(clearedAt)).toList();
    await _repository.upsertMessages(toUpsert);
    if (toUpsert.isNotEmpty) {
      await _unhideConversationIfNeeded();
    }
    ref.invalidate(conversationSummariesProvider);
    final local = await _repository.listMessages(
      conversationId: arg,
      limit: 200,
    );
    state = AsyncData(local);
  }

  Future<void> sendMessage({
    required String baseUrl,
    required String accessToken,
    required String currentUserId,
    required String body,
    String? recipientServerUrl,
  }) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final sent = _isRoomConversation
        ? await _remoteChatService.sendRoomMessage(
            baseUrl: baseUrl,
            accessToken: accessToken,
            roomId: _roomId,
            body: trimmed,
          )
        : await (() async {
            final senderPublicKey = await _e2eeService
                .ensureDevicePublicKeyBase64();
            final recipientPublicKey = await _resolveRecipientPublicKey(
              baseUrl: baseUrl,
              accessToken: accessToken,
            );
            return _remoteChatService.sendMessage(
              baseUrl: baseUrl,
              accessToken: accessToken,
              currentUserId: currentUserId,
              senderPublicKey: senderPublicKey,
              recipientPublicKey: recipientPublicKey,
              partnerId: arg,
              body: trimmed,
              recipientServerUrl: recipientServerUrl,
            );
          })();

    await _repository.upsertMessages([sent]);
    await _unhideConversationIfNeeded();
    ref.invalidate(conversationSummariesProvider);
    if (_isRoomConversation) {
      await _remoteChatService.markRoomRead(
        baseUrl: baseUrl,
        accessToken: accessToken,
        roomId: _roomId,
      );
      await ref
          .read(roomConversationsProvider.notifier)
          .markRoomReadLocal(_roomId);
    } else {
      await _remoteChatService.markRead(
        baseUrl: baseUrl,
        accessToken: accessToken,
        partnerId: arg,
      );
    }

    final local = await _repository.listMessages(
      conversationId: arg,
      limit: 200,
    );
    state = AsyncData(local);
  }

  Future<String> _resolveRecipientPublicKey({
    required String baseUrl,
    required String accessToken,
  }) async {
    final now = DateTime.now();
    final cached = _cachedRecipientPublicKey;
    final cachedAt = _cachedRecipientPublicKeyAt;
    if (cached != null &&
        cached.isNotEmpty &&
        cachedAt != null &&
        now.difference(cachedAt) < _recipientKeyCacheTtl) {
      return cached;
    }

    final partnerProfile = await _profileService.getUserProfile(
      baseUrl: baseUrl,
      accessToken: accessToken,
      userId: arg,
    );
    final recipientPublicKey = partnerProfile.messagePublicKey?.trim();
    if (recipientPublicKey == null || recipientPublicKey.isEmpty) {
      throw StateError(
        'Recipient has no secure chat key yet. Ask them to sign in again.',
      );
    }

    _cachedRecipientPublicKey = recipientPublicKey;
    _cachedRecipientPublicKeyAt = now;
    return recipientPublicKey;
  }

  Future<int> markRead({required String baseUrl, required String accessToken}) {
    if (_isRoomConversation) {
      return _remoteChatService.markRoomRead(
        baseUrl: baseUrl,
        accessToken: accessToken,
        roomId: _roomId,
      );
    }
    return _remoteChatService.markRead(
      baseUrl: baseUrl,
      accessToken: accessToken,
      partnerId: arg,
    );
  }
}
