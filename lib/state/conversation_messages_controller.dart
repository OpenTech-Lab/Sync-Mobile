import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_controller.dart';
import '../models/chat_room.dart';
import '../models/local_chat_message.dart';
import '../services/backup_preferences.dart';
import '../services/local_chat_repository.dart';
import '../services/message_e2ee_service.dart';
import '../services/objectionable_content_filter.dart';
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

const reportedMessageHiddenPlaceholder = '[Message hidden after report]';

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

  Future<RoomDetail> renameRoom({
    required String baseUrl,
    required String accessToken,
    required String roomId,
    required String name,
  }) async {
    final detail = await _remoteChatService.renameRoom(
      baseUrl: baseUrl,
      accessToken: accessToken,
      roomId: roomId,
      name: name,
    );
    await syncRooms(baseUrl: baseUrl, accessToken: accessToken);
    return detail;
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
    await ref.read(hiddenConversationIdsProvider.notifier).unhide(arg);
  }

  Future<void> concealReportedMessage(LocalChatMessage message) async {
    final repository = ref.read(chatRepositoryProvider);
    final concealed = message.copyWith(body: reportedMessageHiddenPlaceholder);
    final current = state.value;
    if (current != null) {
      state = AsyncData([
        for (final item in current) item.id == message.id ? concealed : item,
      ]);
    }
    await repository.replaceMessage(concealed);
    ref.invalidate(conversationSummariesProvider);
  }

  /// Maximum number of `after`-cursor pages fetched per [syncLatest] call, so
  /// a server that never reports a short page (e.g. one ignoring `after`,
  /// see [_fetchIncremental]) can't turn catch-up into an unbounded loop.
  static const _maxCatchUpPages = 10;

  /// Local-only rows queued before the server assigned a real id (see
  /// [ChatRepository.addMessage]) are never usable as an incremental-sync
  /// cursor — only a server-assigned id guarantees `after=<id>` means
  /// anything to the server.
  bool _hasServerId(LocalChatMessage message) =>
      !message.id.startsWith('m_');

  /// Fetches messages newer than the newest locally-known server message and
  /// merges them into local storage, falling back to the old "latest page"
  /// fetch when there is no usable cursor or the incremental request fails
  /// (e.g. an old server that doesn't understand `after`, or the cursor
  /// message has since been deleted server-side).
  ///
  /// Returns whether the sync completed successfully, so callers that must
  /// not proceed on a failed sync (see [MainShell]'s resume handling) can
  /// gate on it.
  Future<bool> syncLatest({
    required String baseUrl,
    required String accessToken,
    required String currentUserId,
  }) async {
    var success = false;
    try {
      final cursor = await _findLocalCursor();
      List<LocalChatMessage> fetched;
      if (cursor == null) {
        fetched = await _fetchLatestPage(
          baseUrl: baseUrl,
          accessToken: accessToken,
          currentUserId: currentUserId,
        );
      } else {
        try {
          fetched = await _fetchIncremental(
            baseUrl: baseUrl,
            accessToken: accessToken,
            currentUserId: currentUserId,
            cursor: cursor,
          );
        } catch (_) {
          // Unknown cursor (404), an old server that rejects/ignores `after`,
          // or a transient network error — fall back to the plain fetch.
          fetched = await _fetchLatestPage(
            baseUrl: baseUrl,
            accessToken: accessToken,
            currentUserId: currentUserId,
          );
        }
      }

      // Don't restore messages that pre-date a local-data deletion.
      final clearedAt = await _latestClearedAt(baseUrl);
      final toUpsert = clearedAt == null
          ? fetched
          : fetched.where((m) => m.createdAt.isAfter(clearedAt)).toList();

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
      success = true;
    } catch (_) {
      // Network unavailable — fall through to show local cache below.
    } finally {
      // Always resolve the provider with whatever is in local storage so the
      // UI shows cached history even when the server is unreachable.
      final local = await _repository.listMessages(
        conversationId: arg,
        limit: 200,
      );
      state = AsyncData(local);
    }
    return success;
  }

  /// The newest locally-stored message id that is safe to use as an `after`
  /// cursor, or null if none of the messages we have locally came from the
  /// server (e.g. a brand-new conversation).
  Future<String?> _findLocalCursor() async {
    // listMessages is newest-first, so the first server-sourced id we see is
    // the correct cursor.
    final local = await _repository.listMessages(
      conversationId: arg,
      limit: 200,
    );
    for (final message in local) {
      if (_hasServerId(message)) {
        return message.id;
      }
    }
    return null;
  }

  Future<List<LocalChatMessage>> _fetchLatestPage({
    required String baseUrl,
    required String accessToken,
    required String currentUserId,
  }) {
    return _isRoomConversation
        ? _remoteChatService.getRoomMessages(
            baseUrl: baseUrl,
            accessToken: accessToken,
            roomId: _roomId,
            limit: 30,
          )
        : _remoteChatService.getConversation(
            baseUrl: baseUrl,
            accessToken: accessToken,
            currentUserId: currentUserId,
            partnerId: arg,
            limit: 30,
          );
  }

  /// Pages forward from [cursor] with `after`, advancing to the newest id
  /// seen in each page, until a page comes back short (fewer than the
  /// requested limit), a page adds nothing we haven't already seen this call
  /// (guards against a server that ignores `after` and keeps returning the
  /// same latest page), or [_maxCatchUpPages] pages have been fetched.
  Future<List<LocalChatMessage>> _fetchIncremental({
    required String baseUrl,
    required String accessToken,
    required String currentUserId,
    required String cursor,
  }) async {
    const pageLimit = 100;
    final collected = <LocalChatMessage>[];
    final seenIds = <String>{};
    var afterId = cursor;

    for (var page = 0; page < _maxCatchUpPages; page++) {
      final batch = _isRoomConversation
          ? await _remoteChatService.getRoomMessages(
              baseUrl: baseUrl,
              accessToken: accessToken,
              roomId: _roomId,
              after: afterId,
              limit: pageLimit,
            )
          : await _remoteChatService.getConversation(
              baseUrl: baseUrl,
              accessToken: accessToken,
              currentUserId: currentUserId,
              partnerId: arg,
              after: afterId,
              limit: pageLimit,
            );
      if (batch.isEmpty) {
        break;
      }

      final newInBatch = batch.where((m) => !seenIds.contains(m.id)).toList();
      if (newInBatch.isEmpty) {
        break;
      }
      seenIds.addAll(newInBatch.map((m) => m.id));
      collected.addAll(newInBatch);

      // Pick the newest id by timestamp rather than assuming an order, so an
      // old server that ignores `after` and replies newest-first still moves
      // the cursor forward instead of looping on the same page.
      afterId = batch
          .reduce((a, b) => a.createdAt.isAfter(b.createdAt) ? a : b)
          .id;

      if (batch.length < pageLimit) {
        break;
      }
    }

    return collected;
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

    try {
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
    } catch (_) {
      // Network unavailable — keep showing the messages already in state.
    }
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
    final textOnly = trimmed
        .replaceAll(RegExp(r'\[media-data:[A-Za-z0-9+/=]{100,}\]'), '')
        .trim();
    ensureUserGeneratedTextAllowed('Message', textOnly);

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
    // The message is already sent and stored at this point — a read-receipt
    // failure below must not be reported as a send failure (it previously
    // propagated out of sendMessage, which the UI treated as a failed send
    // and retried, duplicating the message on the server).
    if (_isRoomConversation) {
      try {
        await _remoteChatService.markRoomRead(
          baseUrl: baseUrl,
          accessToken: accessToken,
          roomId: _roomId,
        );
        await ref
            .read(roomConversationsProvider.notifier)
            .markRoomReadLocal(_roomId);
      } catch (_) {
        // Best-effort; see comment above.
      }
    } else {
      try {
        await _remoteChatService.markRead(
          baseUrl: baseUrl,
          accessToken: accessToken,
          partnerId: arg,
        );
      } catch (_) {
        // Best-effort; see comment above.
      }
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
