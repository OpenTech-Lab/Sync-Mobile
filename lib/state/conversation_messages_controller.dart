import 'package:flutter/foundation.dart'
  show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/local_chat_message.dart';
import '../services/local_chat_repository.dart';
import '../services/remote_chat_service.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final supportsEncryptedLocalDb = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  // sqflite_sqlcipher is not available on web/linux/windows.
  return supportsEncryptedLocalDb
      ? LocalChatRepository()
      : InMemoryChatRepository();
});

final remoteChatServiceProvider = Provider<RemoteChatService>((ref) {
  return RemoteChatService();
});

final conversationMessagesProvider = AsyncNotifierProviderFamily<
    ConversationMessagesController,
    List<LocalChatMessage>,
    String>(ConversationMessagesController.new);

class ConversationMessagesController
    extends FamilyAsyncNotifier<List<LocalChatMessage>, String> {
  ChatRepository get _repository => ref.read(chatRepositoryProvider);
  RemoteChatService get _remoteChatService => ref.read(remoteChatServiceProvider);

  @override
  Future<List<LocalChatMessage>> build(String partnerId) {
    return _repository.listMessages(conversationId: partnerId, limit: 200);
  }

  Future<void> syncLatest({
    required String baseUrl,
    required String accessToken,
  }) async {
    final latest = await _remoteChatService.getConversation(
      baseUrl: baseUrl,
      accessToken: accessToken,
      partnerId: arg,
      limit: 30,
    );

    await _repository.upsertMessages(latest);
    final local = await _repository.listMessages(conversationId: arg, limit: 200);
    state = AsyncData(local);
  }

  Future<void> loadMore({
    required String baseUrl,
    required String accessToken,
  }) async {
    final current = state.value ?? [];
    if (current.isEmpty) {
      await syncLatest(baseUrl: baseUrl, accessToken: accessToken);
      return;
    }

    final before = current.last.id;
    final older = await _remoteChatService.getConversation(
      baseUrl: baseUrl,
      accessToken: accessToken,
      partnerId: arg,
      before: before,
      limit: 30,
    );

    await _repository.upsertMessages(older);
    final local = await _repository.listMessages(conversationId: arg, limit: 200);
    state = AsyncData(local);
  }

  Future<void> sendMessage({
    required String baseUrl,
    required String accessToken,
    required String body,
  }) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final sent = await _remoteChatService.sendMessage(
      baseUrl: baseUrl,
      accessToken: accessToken,
      partnerId: arg,
      body: trimmed,
    );

    await _repository.upsertMessages([sent]);
    await _remoteChatService.markRead(
      baseUrl: baseUrl,
      accessToken: accessToken,
      partnerId: arg,
    );

    final local = await _repository.listMessages(conversationId: arg, limit: 200);
    state = AsyncData(local);
  }

  Future<int> markRead({
    required String baseUrl,
    required String accessToken,
  }) {
    return _remoteChatService.markRead(
      baseUrl: baseUrl,
      accessToken: accessToken,
      partnerId: arg,
    );
  }
}
