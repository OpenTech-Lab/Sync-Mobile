import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/chat_room.dart';
import 'package:mobile/models/local_chat_message.dart';
import 'package:mobile/models/user_profile.dart';
import 'package:mobile/services/local_chat_repository.dart';
import 'package:mobile/services/message_e2ee_service.dart';
import 'package:mobile/services/remote_chat_service.dart';
import 'package:mobile/services/remote_user_profile_service.dart';
import 'package:mobile/state/conversation_messages_controller.dart';
import 'package:mobile/state/user_profile_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _InMemoryChatRepository implements ChatRepository {
  final List<LocalChatMessage> _messages = [];
  final Map<String, ChatRoom> _rooms = {};

  @override
  Future<void> addMessage({
    required String conversationId,
    required String senderId,
    required String body,
  }) async {
    _messages.add(
      LocalChatMessage(
        id: 'local-${_messages.length + 1}',
        conversationId: conversationId,
        senderId: senderId,
        body: body,
        createdAt: DateTime.utc(2026, 3, 2, 12, 0, _messages.length),
      ),
    );
  }

  @override
  Future<void> clearConversation(String conversationId) async {
    _messages.removeWhere(
      (message) => message.conversationId == conversationId,
    );
  }

  @override
  Future<List<LocalChatMessage>> listMessages({
    required String conversationId,
    int limit = 100,
  }) async {
    return _messages
        .where((message) => message.conversationId == conversationId)
        .toList(growable: false)
        .reversed
        .take(limit)
        .toList(growable: false);
  }

  @override
  Future<void> upsertMessages(List<LocalChatMessage> messages) async {
    for (final message in messages) {
      final exists = _messages.any((existing) => existing.id == message.id);
      if (!exists) {
        _messages.add(message);
      }
    }
  }

  @override
  Future<List<LocalChatMessage>> listAllMessages() async {
    return _messages.toList(growable: false);
  }

  @override
  Future<void> replaceAllMessages(List<LocalChatMessage> messages) async {
    _messages
      ..clear()
      ..addAll(messages);
  }

  @override
  Future<List<ConversationSummary>> listConversations() async {
    final grouped = <String, List<LocalChatMessage>>{};
    for (final message in _messages) {
      (grouped[message.conversationId] ??= <LocalChatMessage>[]).add(message);
    }

    final summaries = <ConversationSummary>[];
    for (final entry in grouped.entries) {
      entry.value.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      summaries.add(
        ConversationSummary(
          conversationId: entry.key,
          lastBody: entry.value.first.body,
          lastAt: entry.value.first.createdAt,
        ),
      );
    }
    summaries.sort((a, b) => b.lastAt.compareTo(a.lastAt));
    return summaries;
  }

  @override
  Future<List<ChatRoom>> listRooms() async {
    return _rooms.values.toList(growable: false);
  }

  @override
  Future<ChatRoom?> readRoom(String roomId) async {
    return _rooms[roomId];
  }

  @override
  Future<void> replaceRooms(List<ChatRoom> rooms) async {
    _rooms
      ..clear()
      ..addEntries(rooms.map((room) => MapEntry(room.id, room)));
  }

  @override
  Future<void> updateRoomUnreadCount({
    required String roomId,
    required int unreadCount,
  }) async {
    final room = _rooms[roomId];
    if (room == null) {
      return;
    }
    _rooms[roomId] = room.copyWith(unreadCount: unreadCount);
  }
}

class _FakeRemoteChatService extends RemoteChatService {
  _FakeRemoteChatService(this._pages) : super();

  final Map<String, List<List<LocalChatMessage>>> _pages;
  final Map<String, int> _pageIndexes = {};

  @override
  Future<List<LocalChatMessage>> getConversation({
    required String baseUrl,
    required String accessToken,
    required String currentUserId,
    required String partnerId,
    String? before,
    int limit = 30,
  }) async {
    final pageIndex = _pageIndexes[partnerId] ?? 0;
    final pages = _pages[partnerId] ?? const [];
    if (pageIndex >= pages.length) {
      return const [];
    }
    _pageIndexes[partnerId] = pageIndex + 1;
    return pages[pageIndex];
  }

  @override
  Future<LocalChatMessage> sendMessage({
    required String baseUrl,
    required String accessToken,
    required String currentUserId,
    required String senderPublicKey,
    required String recipientPublicKey,
    required String partnerId,
    required String body,
    String? recipientServerUrl,
  }) async {
    return LocalChatMessage(
      id: 'sent-1',
      conversationId: partnerId,
      senderId: 'me',
      body: body,
      createdAt: DateTime.utc(2026, 3, 2, 12, 1),
    );
  }

  @override
  Future<int> markRead({
    required String baseUrl,
    required String accessToken,
    required String partnerId,
  }) async {
    return 1;
  }

  @override
  Future<List<LocalChatMessage>> getRoomMessages({
    required String baseUrl,
    required String accessToken,
    required String roomId,
    String? before,
    int limit = 50,
  }) async {
    final conversationId = roomConversationId(roomId);
    final pageIndex = _pageIndexes[conversationId] ?? 0;
    final pages = _pages[conversationId] ?? const [];
    if (pageIndex >= pages.length) {
      return const [];
    }
    _pageIndexes[conversationId] = pageIndex + 1;
    return pages[pageIndex];
  }

  @override
  Future<LocalChatMessage> sendRoomMessage({
    required String baseUrl,
    required String accessToken,
    required String roomId,
    required String body,
  }) async {
    return LocalChatMessage(
      id: 'room-sent-1',
      conversationId: roomConversationId(roomId),
      senderId: 'me',
      body: body,
      createdAt: DateTime.utc(2026, 3, 2, 12, 1),
    );
  }

  @override
  Future<int> markRoomRead({
    required String baseUrl,
    required String accessToken,
    required String roomId,
  }) async {
    return 1;
  }
}

class _FakeRemoteUserProfileService extends RemoteUserProfileService {
  _FakeRemoteUserProfileService();

  static const _publicKey = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=';

  @override
  Future<UserProfile> getMyProfile({
    required String baseUrl,
    required String accessToken,
  }) async {
    return const UserProfile(
      id: 'me',
      username: 'me',
      avatarBase64: null,
      description: null,
      messagePublicKey: _publicKey,
    );
  }

  @override
  Future<UserProfile> getUserProfile({
    required String baseUrl,
    required String accessToken,
    required String userId,
  }) async {
    return UserProfile(
      id: userId,
      username: userId,
      avatarBase64: null,
      description: null,
      messagePublicKey: _publicKey,
    );
  }

  @override
  Future<UserProfile> updateMyProfile({
    required String baseUrl,
    required String accessToken,
    String? username,
    String? avatarBase64,
    String? description,
    String? messagePublicKey,
    bool clearAvatar = false,
    bool clearDescription = false,
  }) async {
    return const UserProfile(
      id: 'me',
      username: 'me',
      avatarBase64: null,
      description: null,
      messagePublicKey: _publicKey,
    );
  }
}

class _FakeMessageE2eeService extends MessageE2eeService {
  _FakeMessageE2eeService();

  static const _publicKey = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=';

  @override
  Future<String?> readStoredPublicKey() async => _publicKey;

  @override
  Future<String> ensureDevicePublicKeyBase64() async => _publicKey;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(const <String, Object>{});
  const partnerId = '11111111-1111-1111-1111-111111111111';

  test('syncLatest caches remote messages in local store', () async {
    final repo = _InMemoryChatRepository();
    final remote = _FakeRemoteChatService({
      partnerId: [
        [
          LocalChatMessage(
            id: 'r1',
            conversationId: partnerId,
            senderId: 'other',
            body: 'hello',
            createdAt: DateTime.utc(2026, 3, 2, 12, 0),
          ),
        ],
      ],
    });

    final container = ProviderContainer(
      overrides: [
        chatRepositoryProvider.overrideWithValue(repo),
        remoteChatServiceProvider.overrideWithValue(remote),
      ],
    );
    addTearDown(container.dispose);

    await container.read(conversationMessagesProvider(partnerId).future);
    await container
        .read(conversationMessagesProvider(partnerId).notifier)
        .syncLatest(
          baseUrl: 'http://localhost:8080',
          accessToken: 'token',
          currentUserId: 'me',
        );

    final messages = container
        .read(conversationMessagesProvider(partnerId))
        .value!;
    expect(messages, hasLength(1));
    expect(messages.first.id, 'r1');
  });

  test('loadMore appends older page without duplicates', () async {
    final repo = _InMemoryChatRepository();
    final remote = _FakeRemoteChatService({
      partnerId: [
        [
          LocalChatMessage(
            id: 'r2',
            conversationId: partnerId,
            senderId: 'other',
            body: 'newest',
            createdAt: DateTime.utc(2026, 3, 2, 12, 1),
          ),
        ],
        [
          LocalChatMessage(
            id: 'r1',
            conversationId: partnerId,
            senderId: 'other',
            body: 'older',
            createdAt: DateTime.utc(2026, 3, 2, 12, 0),
          ),
        ],
      ],
    });

    final container = ProviderContainer(
      overrides: [
        chatRepositoryProvider.overrideWithValue(repo),
        remoteChatServiceProvider.overrideWithValue(remote),
      ],
    );
    addTearDown(container.dispose);

    await container.read(conversationMessagesProvider(partnerId).future);
    await container
        .read(conversationMessagesProvider(partnerId).notifier)
        .syncLatest(
          baseUrl: 'http://localhost:8080',
          accessToken: 'token',
          currentUserId: 'me',
        );
    await container
        .read(conversationMessagesProvider(partnerId).notifier)
        .loadMore(
          baseUrl: 'http://localhost:8080',
          accessToken: 'token',
          currentUserId: 'me',
        );

    final messages = container
        .read(conversationMessagesProvider(partnerId))
        .value!;
    expect(messages, hasLength(2));
    expect(messages.map((message) => message.id), containsAll(['r1', 'r2']));
  });

  test('sendMessage persists server-created message locally', () async {
    final repo = _InMemoryChatRepository();
    final remote = _FakeRemoteChatService({partnerId: const []});

    final container = ProviderContainer(
      overrides: [
        chatRepositoryProvider.overrideWithValue(repo),
        remoteChatServiceProvider.overrideWithValue(remote),
        remoteUserProfileServiceProvider.overrideWithValue(
          _FakeRemoteUserProfileService(),
        ),
        messageE2eeServiceProvider.overrideWithValue(_FakeMessageE2eeService()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(conversationMessagesProvider(partnerId).future);
    await container
        .read(conversationMessagesProvider(partnerId).notifier)
        .sendMessage(
          baseUrl: 'http://localhost:8080',
          accessToken: 'token',
          currentUserId: 'me',
          body: 'hi',
        );

    final messages = container
        .read(conversationMessagesProvider(partnerId))
        .value!;
    expect(messages, hasLength(1));
    expect(messages.first.id, 'sent-1');
    expect(messages.first.body, 'hi');
  });
}
