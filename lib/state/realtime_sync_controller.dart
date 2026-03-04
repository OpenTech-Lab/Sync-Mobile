import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/local_chat_message.dart';
import '../models/realtime_event.dart';
import '../services/realtime_sync_service.dart';
import '../services/notification_service.dart';
import 'chat_visibility_controller.dart';
import 'conversation_messages_controller.dart';
import 'unread_counts_controller.dart';

class RealtimeSyncState {
  const RealtimeSyncState({
    required this.status,
    required this.error,
    required this.typingPartnerIds,
  });

  final RealtimeConnectionStatus status;
  final String? error;
  final Set<String> typingPartnerIds;

  RealtimeSyncState copyWith({
    RealtimeConnectionStatus? status,
    String? error,
    Set<String>? typingPartnerIds,
  }) {
    return RealtimeSyncState(
      status: status ?? this.status,
      error: error,
      typingPartnerIds: typingPartnerIds ?? this.typingPartnerIds,
    );
  }
}

final realtimeSyncServiceProvider = Provider<RealtimeSyncService>((ref) {
  final service = RealtimeSyncService();
  ref.onDispose(service.dispose);
  return service;
});

final realtimeNotificationServiceProvider = Provider<NotificationService>((_) {
  return NotificationService();
});

final realtimeSyncControllerProvider =
    AsyncNotifierProvider<RealtimeSyncController, RealtimeSyncState>(
      RealtimeSyncController.new,
    );

class RealtimeSyncController extends AsyncNotifier<RealtimeSyncState> {
  StreamSubscription<RealtimeEvent>? _subscription;
  final Set<String> _conversationSyncInFlight = <String>{};

  @override
  Future<RealtimeSyncState> build() async {
    return const RealtimeSyncState(
      status: RealtimeConnectionStatus.disconnected,
      error: null,
      typingPartnerIds: <String>{},
    );
  }

  Future<void> connect({
    required String baseUrl,
    required Future<String?> Function() accessTokenProvider,
    required String currentUserId,
  }) async {
    final service = ref.read(realtimeSyncServiceProvider);

    await _subscription?.cancel();
    _subscription = service.events.listen((event) async {
      final current =
          state.value ??
          const RealtimeSyncState(
            status: RealtimeConnectionStatus.disconnected,
            error: null,
            typingPartnerIds: <String>{},
          );

      if (event.connectionStatus != null) {
        state = AsyncData(
          current.copyWith(status: event.connectionStatus, error: null),
        );
      }

      if (event.error != null) {
        state = AsyncData(
          current.copyWith(
            status: RealtimeConnectionStatus.reconnecting,
            error: event.error,
          ),
        );
      }

      if (event.typingPartnerId != null && event.isTyping != null) {
        final nextTyping = {...current.typingPartnerIds};
        if (event.isTyping!) {
          nextTyping.add(event.typingPartnerId!);
        } else {
          nextTyping.remove(event.typingPartnerId!);
        }
        state = AsyncData(current.copyWith(typingPartnerIds: nextTyping));
      }

      if (event.message != null) {
        var message = event.message!;
        final e2eeService = ref.read(messageE2eeServiceProvider);
        final decrypted = await e2eeService.tryDecryptEnvelope(
          content: message.body,
          sentByCurrentUser: message.senderId == currentUserId,
        );
        if (decrypted != null) {
          message = LocalChatMessage(
            id: message.id,
            conversationId: message.conversationId,
            senderId: message.senderId,
            body: decrypted,
            createdAt: message.createdAt,
          );
        }
        final typingAfterMessage = {...current.typingPartnerIds}
          ..remove(message.conversationId);
        state = AsyncData(
          current.copyWith(typingPartnerIds: typingAfterMessage),
        );
        await ref.read(chatRepositoryProvider).upsertMessages([message]);
        final partnerId = message.conversationId;
        final accessToken = await accessTokenProvider();
        if (accessToken == null || accessToken.isEmpty) {
          ref.invalidate(conversationMessagesProvider(partnerId));
          ref.invalidate(conversationSummariesProvider);
          return;
        }
        await _syncConversationSnapshot(
          partnerId: partnerId,
          baseUrl: baseUrl,
          accessToken: accessToken,
          currentUserId: currentUserId,
        );
        final visibility = ref.read(chatVisibilityProvider);
        if (!visibility.isConversationOpen(partnerId) &&
            message.senderId != currentUserId) {
          final body = e2eeService.isEncryptedEnvelope(message.body)
              ? 'Sent you an encrypted message'
              : message.body;
          await ref
              .read(realtimeNotificationServiceProvider)
              .showIncomingMessageNotification(
                partnerId: partnerId,
                body: body,
              );
        }
        await ref
            .read(unreadCountsProvider.notifier)
            .refresh(baseUrl: baseUrl, accessToken: accessToken);
      }
    });

    await service.connect(
      baseUrl: baseUrl,
      accessTokenProvider: accessTokenProvider,
      currentUserId: currentUserId,
    );
  }

  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;
    await ref.read(realtimeSyncServiceProvider).disconnect();
    final current = state.value;
    if (current != null) {
      state = AsyncData(
        current.copyWith(
          status: RealtimeConnectionStatus.disconnected,
          error: null,
          typingPartnerIds: <String>{},
        ),
      );
    }
  }

  void sendTyping({required String partnerId, required bool isTyping}) {
    ref
        .read(realtimeSyncServiceProvider)
        .sendTyping(partnerId: partnerId, isTyping: isTyping);
  }

  Future<void> _syncConversationSnapshot({
    required String partnerId,
    required String baseUrl,
    required String accessToken,
    required String currentUserId,
  }) async {
    if (_conversationSyncInFlight.contains(partnerId)) {
      return;
    }

    _conversationSyncInFlight.add(partnerId);
    try {
      await ref
          .read(conversationMessagesProvider(partnerId).notifier)
          .syncLatest(
            baseUrl: baseUrl,
            accessToken: accessToken,
            currentUserId: currentUserId,
          );
    } catch (_) {
      // Keep UI reactive even if remote sync fails transiently.
      ref.invalidate(conversationMessagesProvider(partnerId));
      ref.invalidate(conversationSummariesProvider);
    } finally {
      _conversationSyncInFlight.remove(partnerId);
    }
  }
}
