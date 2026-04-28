import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/calls/call_controller.dart';
import '../models/chat_room.dart';
import '../models/local_chat_message.dart';
import '../models/realtime_event.dart';
import '../services/realtime_sync_service.dart';
import '../services/notification_service.dart';
import 'user_profile_controller.dart';
import 'chat_visibility_controller.dart';
import 'conversation_messages_controller.dart';
import 'backup_controller.dart';
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
  static const _encryptedFallbackMessage =
      '[Encrypted message: key unavailable on this device]';
  StreamSubscription<RealtimeEvent>? _subscription;
  final Set<String> _conversationSyncInFlight = <String>{};

  String? _baseUrl;
  Future<String?> Function()? _accessTokenProvider;

  /// The server base URL from the most recent [connect] call.
  String? get baseUrl => _baseUrl;

  /// Live access-token provider from the most recent [connect] call.
  Future<String?> Function()? get accessTokenProvider => _accessTokenProvider;

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
    _baseUrl = baseUrl;
    _accessTokenProvider = accessTokenProvider;
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

      if (event.roomMembershipChangedRoomId != null) {
        final accessToken = await accessTokenProvider();
        if (accessToken != null && accessToken.isNotEmpty) {
          try {
            await ref
                .read(roomConversationsProvider.notifier)
                .syncRooms(baseUrl: baseUrl, accessToken: accessToken);
          } catch (_) {
            ref.invalidate(conversationSummariesProvider);
          }
        } else {
          ref.invalidate(conversationSummariesProvider);
        }
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
        } else if (e2eeService.isEncryptedEnvelope(message.body)) {
          message = LocalChatMessage(
            id: message.id,
            conversationId: message.conversationId,
            senderId: message.senderId,
            body: _encryptedFallbackMessage,
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
        final isRoomConversation = isRoomConversationId(partnerId);
        final accessToken = await accessTokenProvider();
        if (accessToken == null || accessToken.isEmpty) {
          ref.invalidate(conversationMessagesProvider(partnerId));
          ref.invalidate(conversationSummariesProvider);
          return;
        }
        if (isRoomConversation) {
          try {
            await ref
                .read(roomConversationsProvider.notifier)
                .syncRooms(baseUrl: baseUrl, accessToken: accessToken);
          } catch (_) {
            ref.invalidate(conversationSummariesProvider);
          }
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
          final avatarBase64 = isRoomConversation
              ? null
              : await ref
                    .read(userProfilePreferencesProvider)
                    .readAvatarBase64(baseUrl, partnerId);
          await ref
              .read(realtimeNotificationServiceProvider)
              .showIncomingMessageNotification(avatarBase64: avatarBase64);
        }
        await ref
            .read(unreadCountsProvider.notifier)
            .refresh(baseUrl: baseUrl, accessToken: accessToken);
        await ref
            .read(backupControllerProvider.notifier)
            .maybeAutoBackup(baseUrl: baseUrl, accessToken: accessToken);
      }

      if (event.incomingCallId != null) {
        final callerId = event.incomingCallCallerId!;
        final displayName =
            ref.read(userDisplayNameProvider(callerId)).value ?? callerId;
        ref.read(callControllerProvider.notifier).handleIncomingCall(
          callId: event.incomingCallId!,
          callerId: callerId,
          callerDisplayName: displayName,
          callType: event.incomingCallType ?? 'voice',
          sdpOffer: event.incomingCallSdpOffer!,
        );
      }

      if (event.answeredCallId != null) {
        await ref.read(callControllerProvider.notifier).handleCallAnswered(
          callId: event.answeredCallId!,
          sdpAnswer: event.answeredSdpAnswer!,
        );
      }

      if (event.rejectedCallId != null) {
        ref.read(callControllerProvider.notifier).handleCallRejected(
          callId: event.rejectedCallId!,
        );
      }

      if (event.hangupCallId != null) {
        ref.read(callControllerProvider.notifier).handleRemoteHangup(
          callId: event.hangupCallId!,
        );
      }

      if (event.iceCandidateCallId != null) {
        await ref.read(callControllerProvider.notifier).handleIceCandidate(
          callId: event.iceCandidateCallId!,
          candidateJson: {
            'candidate': event.iceCandidate,
            'sdpMid': event.iceSdpMid,
            'sdpMLineIndex': event.iceSdpMlineIndex,
          },
        );
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

  void sendCallSignal(Map<String, dynamic> payload) {
    ref.read(realtimeSyncServiceProvider).sendCallSignal(payload);
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
