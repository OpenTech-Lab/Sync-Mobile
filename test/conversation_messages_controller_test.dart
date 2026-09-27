import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/chat_room.dart';
import 'package:mobile/models/conversation_note.dart';
import 'package:mobile/models/local_chat_message.dart';
import 'package:mobile/models/todo_item.dart';
import 'package:mobile/models/user_profile.dart';
import 'package:mobile/services/backup_preferences.dart';
import 'package:mobile/services/local_chat_repository.dart';
import 'package:mobile/services/message_e2ee_service.dart';
import 'package:mobile/services/remote_chat_service.dart';
import 'package:mobile/services/server_scope.dart';
import 'package:mobile/services/remote_user_profile_service.dart';
import 'package:mobile/state/app_controller.dart';
import 'package:mobile/state/conversation_messages_controller.dart';
import 'package:mobile/state/hidden_conversation_ids_controller.dart';
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
  Future<void> replaceMessage(LocalChatMessage message) async {
    final idx = _messages.indexWhere((existing) => existing.id == message.id);
    if (idx == -1) {
      _messages.add(message);
    } else {
      _messages[idx] = message;
    }
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

  final _notes = <String, ConversationNote>{};
  final _todos = <String, List<TodoItem>>{};

  @override
  Future<ConversationNote?> readNote(String conversationId) async {
    return _notes[conversationId];
  }

  @override
  Future<void> saveNote(ConversationNote note) async {
    _notes[note.conversationId] = note;
  }

  @override
  Future<List<TodoItem>> listTodos(String conversationId) async {
    return [...(_todos[conversationId] ?? <TodoItem>[])];
  }

  @override
  Future<void> upsertTodo(TodoItem todo) async {
    final list = _todos[todo.conversationId] ??= [];
    final idx = list.indexWhere((e) => e.id == todo.id);
    if (idx == -1) {
      list.add(todo);
    } else {
      list[idx] = todo;
    }
  }

  @override
  Future<void> deleteTodo(String todoId) async {
    for (final list in _todos.values) {
      list.removeWhere((e) => e.id == todoId);
    }
  }

  @override
  Future<void> replaceTodos(
    String conversationId,
    List<TodoItem> todos,
  ) async {
    _todos[conversationId] = [...todos];
  }
}

class _FakeRemoteChatService extends RemoteChatService {
  _FakeRemoteChatService(
    this._pages, {
    Map<String, List<List<LocalChatMessage>>> afterPages = const {},
    Set<String> afterThrowsFor = const {},
  }) : _afterPages = afterPages,
       _afterThrowsFor = afterThrowsFor,
       super();

  final Map<String, List<List<LocalChatMessage>>> _pages;
  final Map<String, int> _pageIndexes = {};

  // Separate paging state for `after`-cursor requests, so a test can drive
  // incremental catch-up independently of the plain "latest page" fetch.
  final Map<String, List<List<LocalChatMessage>>> _afterPages;
  final Map<String, int> _afterPageIndexes = {};
  final Set<String> _afterThrowsFor;
  int afterCallCount = 0;
  int plainCallCount = 0;

  @override
  Future<List<LocalChatMessage>> getConversation({
    required String baseUrl,
    required String accessToken,
    required String currentUserId,
    required String partnerId,
    String? before,
    String? after,
    int limit = 30,
  }) async {
    if (after != null) {
      afterCallCount++;
      if (_afterThrowsFor.contains(partnerId)) {
        throw const RemoteChatApiException(
          message: 'unknown cursor',
          statusCode: 404,
        );
      }
      final pageIndex = _afterPageIndexes[partnerId] ?? 0;
      final pages = _afterPages[partnerId] ?? const [];
      if (pageIndex >= pages.length) {
        return const [];
      }
      _afterPageIndexes[partnerId] = pageIndex + 1;
      return pages[pageIndex];
    }

    plainCallCount++;
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

  bool markReadThrows = false;

  @override
  Future<int> markRead({
    required String baseUrl,
    required String accessToken,
    required String partnerId,
  }) async {
    if (markReadThrows) {
      throw const RemoteChatApiException(
        message: 'mark read failed',
        statusCode: 500,
      );
    }
    return 1;
  }

  @override
  Future<List<LocalChatMessage>> getRoomMessages({
    required String baseUrl,
    required String accessToken,
    required String roomId,
    String? before,
    String? after,
    int limit = 50,
  }) async {
    final conversationId = roomConversationId(roomId);
    if (after != null) {
      afterCallCount++;
      if (_afterThrowsFor.contains(conversationId)) {
        throw const RemoteChatApiException(
          message: 'unknown cursor',
          statusCode: 404,
        );
      }
      final pageIndex = _afterPageIndexes[conversationId] ?? 0;
      final pages = _afterPages[conversationId] ?? const [];
      if (pageIndex >= pages.length) {
        return const [];
      }
      _afterPageIndexes[conversationId] = pageIndex + 1;
      return pages[pageIndex];
    }

    plainCallCount++;
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

  test(
    'per-conversation clear timestamp prevents old messages from coming back',
    () async {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      const baseUrl = 'http://localhost:8080';
      final repo = _InMemoryChatRepository();
      final remote = _FakeRemoteChatService({
        partnerId: [
          [
            LocalChatMessage(
              id: 'r2',
              conversationId: partnerId,
              senderId: 'other',
              body: 'new after clear',
              createdAt: DateTime.utc(2026, 3, 2, 12, 5),
            ),
            LocalChatMessage(
              id: 'r1',
              conversationId: partnerId,
              senderId: 'other',
              body: 'old before clear',
              createdAt: DateTime.utc(2026, 3, 2, 12, 0),
            ),
          ],
          [
            LocalChatMessage(
              id: 'r1',
              conversationId: partnerId,
              senderId: 'other',
              body: 'old before clear',
              createdAt: DateTime.utc(2026, 3, 2, 12, 0),
            ),
          ],
        ],
      });

      await BackupPreferences().writeConversationClearedAt(
        serverUrl: baseUrl,
        conversationId: partnerId,
        clearedAt: DateTime.utc(2026, 3, 2, 12, 3),
      );

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
            baseUrl: baseUrl,
            accessToken: 'token',
            currentUserId: 'me',
          );
      await container
          .read(conversationMessagesProvider(partnerId).notifier)
          .loadMore(
            baseUrl: baseUrl,
            accessToken: 'token',
            currentUserId: 'me',
          );

      final messages = container
          .read(conversationMessagesProvider(partnerId))
          .value!;
      expect(messages, hasLength(1));
      expect(messages.first.id, 'r2');
      expect(messages.first.body, 'new after clear');
    },
  );

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

  test(
    'syncLatest unhides room conversations when new room messages arrive',
    () async {
      const baseUrl = 'http://localhost:8080';
      const roomId = 'room-1';
      final conversationId = roomConversationId(roomId);

      SharedPreferences.setMockInitialValues({
        scopedStorageKey('chat_hidden_conversation_ids', baseUrl): <String>[
          conversationId,
        ],
      });

      final repo = _InMemoryChatRepository();
      final remote = _FakeRemoteChatService({
        conversationId: [
          [
            LocalChatMessage(
              id: 'room-r1',
              conversationId: conversationId,
              senderId: 'other',
              body: 'hello room',
              createdAt: DateTime.utc(2026, 3, 12, 12, 0),
            ),
          ],
        ],
      });

      final container = ProviderContainer(
        overrides: [
          activeServerUrlProvider.overrideWithValue(baseUrl),
          chatRepositoryProvider.overrideWithValue(repo),
          remoteChatServiceProvider.overrideWithValue(remote),
        ],
      );
      addTearDown(container.dispose);

      expect(
        await container.read(hiddenConversationIdsProvider.future),
        contains(conversationId),
      );

      await container.read(conversationMessagesProvider(conversationId).future);
      await container
          .read(conversationMessagesProvider(conversationId).notifier)
          .syncLatest(
            baseUrl: baseUrl,
            accessToken: 'token',
            currentUserId: 'me',
          );

      expect(
        container.read(hiddenConversationIdsProvider).value,
        isNot(contains(conversationId)),
      );
    },
  );

  test(
    'concealReportedMessage updates local state and survives syncLatest',
    () async {
      const partnerId = 'friend-1';
      final original = LocalChatMessage(
        id: 'm-1',
        conversationId: partnerId,
        senderId: 'other',
        body: 'report me',
        createdAt: DateTime.utc(2026, 3, 12, 12, 0),
      );
      final repo = _InMemoryChatRepository();
      await repo.replaceAllMessages([original]);
      final remote = _FakeRemoteChatService({
        partnerId: [
          [original],
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
          .concealReportedMessage(original);

      final concealedState = container
          .read(conversationMessagesProvider(partnerId))
          .value!;
      expect(concealedState.single.body, reportedMessageHiddenPlaceholder);

      final concealedStored = await repo.listMessages(conversationId: partnerId);
      expect(concealedStored.single.body, reportedMessageHiddenPlaceholder);

      await container
          .read(conversationMessagesProvider(partnerId).notifier)
          .syncLatest(
            baseUrl: 'http://localhost:8080',
            accessToken: 'token',
            currentUserId: 'me',
          );

      final syncedState = container
          .read(conversationMessagesProvider(partnerId))
          .value!;
      expect(syncedState.single.body, reportedMessageHiddenPlaceholder);
    },
  );

  test(
    'syncLatest pages forward with after once a local cursor exists, '
    'stopping at the first short page',
    () async {
      final repo = _InMemoryChatRepository();
      // Seed a locally-known server message so the next syncLatest call has
      // a cursor to page forward from.
      await repo.upsertMessages([
        LocalChatMessage(
          id: 'cursor-0',
          conversationId: partnerId,
          senderId: 'other',
          body: 'seed',
          createdAt: DateTime.utc(2026, 3, 2, 12, 0),
        ),
      ]);

      List<LocalChatMessage> page(String prefix, int count, int hourOffset) {
        return List.generate(
          count,
          (i) => LocalChatMessage(
            id: '$prefix-$i',
            conversationId: partnerId,
            senderId: 'other',
            body: '$prefix message $i',
            createdAt: DateTime.utc(2026, 3, 2, 13 + hourOffset, i),
          ),
        );
      }

      final firstPage = page('p1', 100, 0); // full page: loop continues
      final secondPage = page('p2', 5, 1); // short page: loop stops here

      final remote = _FakeRemoteChatService(
        const {},
        afterPages: {
          partnerId: [firstPage, secondPage],
        },
      );

      final container = ProviderContainer(
        overrides: [
          chatRepositoryProvider.overrideWithValue(repo),
          remoteChatServiceProvider.overrideWithValue(remote),
        ],
      );
      addTearDown(container.dispose);

      await container.read(conversationMessagesProvider(partnerId).future);
      final success = await container
          .read(conversationMessagesProvider(partnerId).notifier)
          .syncLatest(
            baseUrl: 'http://localhost:8080',
            accessToken: 'token',
            currentUserId: 'me',
          );

      expect(success, isTrue);
      // Two after-cursor pages fetched, and never the plain limit:30 fetch.
      expect(remote.afterCallCount, 2);
      expect(remote.plainCallCount, 0);

      final messages = container
          .read(conversationMessagesProvider(partnerId))
          .value!;
      // Seed message + both pages, all merged in.
      expect(messages, hasLength(1 + firstPage.length + secondPage.length));
      expect(
        messages.map((m) => m.id),
        containsAll(['cursor-0', 'p1-0', 'p1-99', 'p2-0', 'p2-4']),
      );
    },
  );

  test(
    'syncLatest falls back to the plain limit:30 fetch when the after '
    'request fails (e.g. unknown cursor on an old or reset server)',
    () async {
      final repo = _InMemoryChatRepository();
      await repo.upsertMessages([
        LocalChatMessage(
          id: 'cursor-0',
          conversationId: partnerId,
          senderId: 'other',
          body: 'seed',
          createdAt: DateTime.utc(2026, 3, 2, 12, 0),
        ),
      ]);

      final remote = _FakeRemoteChatService(
        {
          partnerId: [
            [
              LocalChatMessage(
                id: 'fallback-1',
                conversationId: partnerId,
                senderId: 'other',
                body: 'fallback',
                createdAt: DateTime.utc(2026, 3, 2, 12, 30),
              ),
            ],
          ],
        },
        afterThrowsFor: {partnerId},
      );

      final container = ProviderContainer(
        overrides: [
          chatRepositoryProvider.overrideWithValue(repo),
          remoteChatServiceProvider.overrideWithValue(remote),
        ],
      );
      addTearDown(container.dispose);

      await container.read(conversationMessagesProvider(partnerId).future);
      final success = await container
          .read(conversationMessagesProvider(partnerId).notifier)
          .syncLatest(
            baseUrl: 'http://localhost:8080',
            accessToken: 'token',
            currentUserId: 'me',
          );

      expect(success, isTrue);
      expect(remote.afterCallCount, 1);
      expect(remote.plainCallCount, 1);

      final messages = container
          .read(conversationMessagesProvider(partnerId))
          .value!;
      expect(messages.map((m) => m.id), containsAll(['cursor-0', 'fallback-1']));
    },
  );

  test(
    'syncLatest reports failure without throwing when the server is '
    'unreachable, so callers can gate on the result',
    () async {
      final repo = _InMemoryChatRepository();
      final remote = _AlwaysThrowingRemoteChatService();

      final container = ProviderContainer(
        overrides: [
          chatRepositoryProvider.overrideWithValue(repo),
          remoteChatServiceProvider.overrideWithValue(remote),
        ],
      );
      addTearDown(container.dispose);

      await container.read(conversationMessagesProvider(partnerId).future);
      final success = await container
          .read(conversationMessagesProvider(partnerId).notifier)
          .syncLatest(
            baseUrl: 'http://localhost:8080',
            accessToken: 'token',
            currentUserId: 'me',
          );

      expect(success, isFalse);
    },
  );

  test(
    'sendMessage does not fail (and so does not trigger a duplicate resend) '
    'when the post-send markRead call fails',
    () async {
      final repo = _InMemoryChatRepository();
      final remote = _FakeRemoteChatService({partnerId: const []})
        ..markReadThrows = true;

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
      // Must complete without throwing.
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
    },
  );
}

class _AlwaysThrowingRemoteChatService extends RemoteChatService {
  _AlwaysThrowingRemoteChatService() : super();

  @override
  Future<List<LocalChatMessage>> getConversation({
    required String baseUrl,
    required String accessToken,
    required String currentUserId,
    required String partnerId,
    String? before,
    String? after,
    int limit = 30,
  }) async {
    throw const RemoteChatApiException(message: 'offline', statusCode: 0);
  }
}
