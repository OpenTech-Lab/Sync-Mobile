import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/remote_safety_service.dart';
import 'app_controller.dart';
import 'conversation_messages_controller.dart';
import 'unread_counts_controller.dart';
import 'user_profile_controller.dart';

final remoteSafetyServiceProvider = Provider<RemoteSafetyService>((ref) {
  return RemoteSafetyService();
});

final blockedUsersProvider = FutureProvider<List<BlockedUser>>((ref) async {
  final appState = await ref.watch(appControllerProvider.future);
  final serverUrl = appState.serverUrl?.trim();
  final accessToken = appState.accessToken?.trim();
  if (serverUrl == null ||
      serverUrl.isEmpty ||
      accessToken == null ||
      accessToken.isEmpty) {
    return const <BlockedUser>[];
  }
  final freshToken =
      await ref.read(appControllerProvider.notifier).ensureFreshAccessToken() ??
      accessToken;
  return ref
      .read(remoteSafetyServiceProvider)
      .listBlockedUsers(baseUrl: serverUrl, accessToken: freshToken);
});

final blockedUserIdsProvider = FutureProvider<Set<String>>((ref) async {
  final blockedUsers = await ref.watch(blockedUsersProvider.future);
  return blockedUsers.map((user) => user.userId).toSet();
});

Future<void> purgeBlockedUserLocally(
  WidgetRef ref, {
  required String serverUrl,
  required String userId,
}) async {
  final repository = ref.read(chatRepositoryProvider);
  final messages = await repository.listAllMessages();
  final retained = messages
      .where(
        (message) =>
            message.conversationId != userId && message.senderId != userId,
      )
      .toList(growable: false);
  await repository.replaceAllMessages(retained);
  await ref
      .read(userProfilePreferencesProvider)
      .removeFriendId(serverUrl, userId);
  ref.invalidate(friendIdsProvider);
  ref.invalidate(friendTagMapProvider);
  ref.invalidate(friendTagsProvider(userId));
  ref.invalidate(friendAddedAtProvider(userId));
  ref.invalidate(conversationMessagesProvider(userId));
  ref.invalidate(conversationSummariesProvider);
}

Future<void> refreshSafetyStateAfterBlock(
  WidgetRef ref, {
  required String baseUrl,
  required String accessToken,
}) async {
  ref.invalidate(blockedUsersProvider);
  ref.invalidate(blockedUserIdsProvider);
  await ref
      .read(unreadCountsProvider.notifier)
      .refresh(baseUrl: baseUrl, accessToken: accessToken);
  try {
    await ref
        .read(roomConversationsProvider.notifier)
        .syncRooms(baseUrl: baseUrl, accessToken: accessToken);
  } catch (_) {
    ref.invalidate(conversationSummariesProvider);
  }
}
