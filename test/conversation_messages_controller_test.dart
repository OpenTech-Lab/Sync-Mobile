import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/local_chat_message.dart';
import 'package:mobile/services/local_chat_repository.dart';
import 'package:mobile/services/remote_chat_service.dart';
import 'package:mobile/state/conversation_messages_controller.dart';

class _InMemoryChatRepository implements ChatRepository {
  final List<LocalChatMessage> _messages = [];

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
    _messages.removeWhere((message) => message.conversationId == conversationId);
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
}

class _FakeRemoteChatService extends RemoteChatService {
  _FakeRemoteChatService(this._pages) : super();

  final Map<String, List<List<LocalChatMessage>>> _pages;
  final Map<String, int> _pageIndexes = {};

  @override
  Future<List<LocalChatMessage>> getConversation({
    required String baseUrl,
    required String accessToken,
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
    required String partnerId,
    required String body,
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
}

void main() {
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
        .syncLatest(baseUrl: 'http://localhost:8080', accessToken: 'token');

    final messages = container.read(conversationMessagesProvider(partnerId)).value!;
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
        .syncLatest(baseUrl: 'http://localhost:8080', accessToken: 'token');
    await container
        .read(conversationMessagesProvider(partnerId).notifier)
        .loadMore(baseUrl: 'http://localhost:8080', accessToken: 'token');

    final messages = container.read(conversationMessagesProvider(partnerId)).value!;
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
      ],
    );
    addTearDown(container.dispose);

    await container.read(conversationMessagesProvider(partnerId).future);
    await container.read(conversationMessagesProvider(partnerId).notifier).sendMessage(
          baseUrl: 'http://localhost:8080',
          accessToken: 'token',
          body: 'hi',
        );

    final messages = container.read(conversationMessagesProvider(partnerId)).value!;
    expect(messages, hasLength(1));
    expect(messages.first.id, 'sent-1');
    expect(messages.first.body, 'hi');
  });
}
