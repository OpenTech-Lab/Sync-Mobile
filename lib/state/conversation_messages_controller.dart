import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/local_chat_message.dart';
import '../services/local_chat_repository.dart';
import '../services/message_e2ee_service.dart';
import '../services/remote_chat_service.dart';
import '../services/remote_user_profile_service.dart';
import 'user_profile_controller.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final supportsEncryptedLocalDb =
      !kIsWeb &&
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

final messageE2eeServiceProvider = Provider<MessageE2eeService>((ref) {
  return MessageE2eeService();
});

final conversationSummariesProvider = FutureProvider<List<ConversationSummary>>(
  (ref) {
    return ref.read(chatRepositoryProvider).listConversations();
  },
);

final conversationMessagesProvider =
    AsyncNotifierProviderFamily<
      ConversationMessagesController,
      List<LocalChatMessage>,
      String
    >(ConversationMessagesController.new);

class ConversationMessagesController
    extends FamilyAsyncNotifier<List<LocalChatMessage>, String> {
  ChatRepository get _repository => ref.read(chatRepositoryProvider);
  RemoteChatService get _remoteChatService =>
      ref.read(remoteChatServiceProvider);
  RemoteUserProfileService get _profileService =>
      ref.read(remoteUserProfileServiceProvider);
  MessageE2eeService get _e2eeService => ref.read(messageE2eeServiceProvider);

  @override
  Future<List<LocalChatMessage>> build(String partnerId) {
    return _repository.listMessages(conversationId: partnerId, limit: 200);
  }

  Future<void> syncLatest({
    required String baseUrl,
    required String accessToken,
    required String currentUserId,
  }) async {
    final latest = await _remoteChatService.getConversation(
      baseUrl: baseUrl,
      accessToken: accessToken,
      currentUserId: currentUserId,
      partnerId: arg,
      limit: 30,
    );

    await _repository.upsertMessages(latest);
    ref.invalidate(conversationSummariesProvider);
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
    final older = await _remoteChatService.getConversation(
      baseUrl: baseUrl,
      accessToken: accessToken,
      currentUserId: currentUserId,
      partnerId: arg,
      before: before,
      limit: 30,
    );

    await _repository.upsertMessages(older);
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

    final me = await _profileService.getMyProfile(
      baseUrl: baseUrl,
      accessToken: accessToken,
    );
    final senderPublicKey = await _e2eeService.readStoredPublicKey();
    if (senderPublicKey == null || senderPublicKey.isEmpty) {
      throw StateError(
        'Secure chat key is missing on this device. Please sign in again.',
      );
    }
    if (me.messagePublicKey != senderPublicKey) {
      await _profileService.updateMyProfile(
        baseUrl: baseUrl,
        accessToken: accessToken,
        messagePublicKey: senderPublicKey,
      );
    }

    final partnerProfile = await _profileService.getUserProfile(
      baseUrl: baseUrl,
      accessToken: accessToken,
      userId: arg,
    );
    final recipientPublicKey = partnerProfile.messagePublicKey;
    if (recipientPublicKey == null || recipientPublicKey.isEmpty) {
      throw StateError(
        'Recipient has no secure chat key yet. Ask them to sign in again.',
      );
    }

    final sent = await _remoteChatService.sendMessage(
      baseUrl: baseUrl,
      accessToken: accessToken,
      currentUserId: currentUserId,
      senderPublicKey: senderPublicKey,
      recipientPublicKey: recipientPublicKey,
      partnerId: arg,
      body: trimmed,
      recipientServerUrl: recipientServerUrl,
    );

    await _repository.upsertMessages([sent]);
    ref.invalidate(conversationSummariesProvider);
    await _remoteChatService.markRead(
      baseUrl: baseUrl,
      accessToken: accessToken,
      partnerId: arg,
    );

    final local = await _repository.listMessages(
      conversationId: arg,
      limit: 200,
    );
    state = AsyncData(local);
  }

  Future<int> markRead({required String baseUrl, required String accessToken}) {
    return _remoteChatService.markRead(
      baseUrl: baseUrl,
      accessToken: accessToken,
      partnerId: arg,
    );
  }
}
