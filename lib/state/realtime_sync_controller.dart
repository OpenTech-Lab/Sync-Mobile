import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/realtime_event.dart';
import '../services/realtime_sync_service.dart';
import '../services/notification_service.dart';
import 'chat_visibility_controller.dart';
import 'conversation_messages_controller.dart';
import 'unread_counts_controller.dart';

class RealtimeSyncState {
  const RealtimeSyncState({required this.status, required this.error});

  final RealtimeConnectionStatus status;
  final String? error;

  RealtimeSyncState copyWith({
    RealtimeConnectionStatus? status,
    String? error,
  }) {
    return RealtimeSyncState(status: status ?? this.status, error: error);
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

  @override
  Future<RealtimeSyncState> build() async {
    return const RealtimeSyncState(
      status: RealtimeConnectionStatus.disconnected,
      error: null,
    );
  }

  Future<void> connect({
    required String baseUrl,
    required Future<String?> Function() accessTokenProvider,
    required String currentUserId,
  }) async {
    final current =
        state.value ??
        const RealtimeSyncState(
          status: RealtimeConnectionStatus.disconnected,
          error: null,
        );

    final service = ref.read(realtimeSyncServiceProvider);

    await _subscription?.cancel();
    _subscription = service.events.listen((event) async {
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

      if (event.message != null) {
        final message = event.message!;
        await ref.read(chatRepositoryProvider).upsertMessages([message]);
        final partnerId = message.conversationId;
        ref.invalidate(conversationMessagesProvider(partnerId));
        ref.invalidate(conversationSummariesProvider);
        final visibility = ref.read(chatVisibilityProvider);
        if (!visibility.isConversationOpen(partnerId) &&
            message.senderId != currentUserId) {
          await ref
              .read(realtimeNotificationServiceProvider)
              .showIncomingMessageNotification(
                partnerId: partnerId,
                body: message.body,
              );
        }
        final accessToken = await accessTokenProvider();
        if (accessToken == null || accessToken.isEmpty) {
          return;
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
        ),
      );
    }
  }
}
