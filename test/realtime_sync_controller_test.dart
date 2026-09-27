import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/chat_room.dart';
import 'package:mobile/models/local_chat_message.dart';
import 'package:mobile/models/realtime_event.dart';
import 'package:mobile/services/message_e2ee_service.dart';
import 'package:mobile/services/local_chat_repository.dart';
import 'package:mobile/services/realtime_sync_service.dart';
import 'package:mobile/services/remote_chat_service.dart';
import 'package:mobile/state/chat_visibility_controller.dart';
import 'package:mobile/state/conversation_messages_controller.dart';
import 'package:mobile/state/realtime_sync_controller.dart';

void main() {
  test('coalesces concurrent connects for the same realtime session', () async {
    final gate = Completer<void>();
    final service = _FakeRealtimeSyncService(connectGate: gate);
    final container = ProviderContainer(
      overrides: [
        realtimeSyncServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await service.close();
    });
    await container.read(realtimeSyncControllerProvider.future);
    final controller = container.read(realtimeSyncControllerProvider.notifier);

    final first = controller.connect(
      baseUrl: 'https://sync.example',
      accessTokenProvider: _token,
      currentUserId: 'user-1',
    );
    await Future<void>.delayed(Duration.zero);
    final second = controller.connect(
      baseUrl: 'https://sync.example',
      accessTokenProvider: _token,
      currentUserId: 'user-1',
    );

    expect(service.connectCount, 1);
    gate.complete();
    await Future.wait([first, second]);
  });

  test('does not replace an already connected realtime socket', () async {
    final service = _FakeRealtimeSyncService();
    final container = ProviderContainer(
      overrides: [
        realtimeSyncServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await service.close();
    });
    await container.read(realtimeSyncControllerProvider.future);
    final controller = container.read(realtimeSyncControllerProvider.notifier);

    await controller.connect(
      baseUrl: 'https://sync.example',
      accessTokenProvider: _token,
      currentUserId: 'user-1',
    );
    await Future<void>.delayed(Duration.zero);
    await controller.connect(
      baseUrl: 'https://sync.example',
      accessTokenProvider: _token,
      currentUserId: 'user-1',
    );

    expect(service.connectCount, 1);
  });

  test(
    'coalesces a conversation catch-up that arrives while one is already '
    'running, rerunning it once more instead of dropping it',
    () async {
      final gate = Completer<void>();
      final remote = _CountingRemoteChatService(gate: gate);
      final service = _FakeRealtimeSyncService();
      final container = ProviderContainer(
        overrides: [
          realtimeSyncServiceProvider.overrideWithValue(service),
          chatRepositoryProvider.overrideWithValue(InMemoryChatRepository()),
          remoteChatServiceProvider.overrideWithValue(remote),
          chatVisibilityProvider.overrideWith(
            (ref) => const ChatVisibilityState(
              isChatsTabSelected: true,
              activePartnerId: 'partner-1',
            ),
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await service.close();
      });
      await container.read(realtimeSyncControllerProvider.future);
      final controller = container.read(realtimeSyncControllerProvider.notifier);

      await controller.connect(
        baseUrl: 'https://sync.example',
        accessTokenProvider: _token,
        currentUserId: 'user-1',
      );
      // Let the fake service's connecting/connected sequence run the first
      // connect-catch-up down to its gated getConversation call.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(remote.getConversationCalls, 1);

      // A second reconnect (e.g. a brief network blip) lands while the first
      // catch-up's sync for partner-1 is still in flight.
      service.emit(RealtimeEvent.connection(RealtimeConnectionStatus.connected));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      // Coalesced, not a second concurrent call.
      expect(remote.getConversationCalls, 1);

      gate.complete();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      // ...but reran once after the first finished, so the second request
      // was not simply dropped.
      expect(remote.getConversationCalls, 2);
    },
  );

  test(
    'events are handled strictly in arrival order: a status change queued '
    'behind a slow decrypt is neither applied early nor lost once its turn '
    'comes',
    () async {
      final decryptGate = Completer<void>();
      final service = _FakeRealtimeSyncService();
      final container = ProviderContainer(
        overrides: [
          realtimeSyncServiceProvider.overrideWithValue(service),
          chatRepositoryProvider.overrideWithValue(InMemoryChatRepository()),
          messageE2eeServiceProvider.overrideWithValue(
            _GatedMessageE2eeService(decryptGate),
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await service.close();
      });
      await container.read(realtimeSyncControllerProvider.future);
      final controller = container.read(realtimeSyncControllerProvider.notifier);

      // No access token: message side effects (network catch-up, etc.) will
      // short-circuit right after the decrypt+upsert this test cares about.
      await controller.connect(
        baseUrl: 'https://sync.example',
        accessTokenProvider: () async => null,
        currentUserId: 'user-1',
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(realtimeSyncControllerProvider).value!.status,
        RealtimeConnectionStatus.connected,
      );

      service.emit(
        RealtimeEvent.message(
          LocalChatMessage(
            id: 'm-1',
            conversationId: 'partner-1',
            senderId: 'other',
            body: 'hello',
            createdAt: DateTime.utc(2026, 1, 1),
          ),
        ),
      );
      // Let processing reach the gated decrypt call — the message handler is
      // now parked mid-await.
      await Future<void>.delayed(Duration.zero);

      // The socket drops while that message is still being decrypted. Under
      // the old, unqueued `listen((event) async {...})` this handler ran
      // concurrently with the message handler and could apply immediately
      // (then get clobbered later by the message handler's stale-snapshot
      // write). With events queued in arrival order, it must instead wait
      // its turn behind the still-in-progress message event.
      service.emit(
        RealtimeEvent.connection(RealtimeConnectionStatus.disconnected),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(realtimeSyncControllerProvider).value!.status,
        RealtimeConnectionStatus.connected,
        reason: 'the disconnect event is still queued behind the pending '
            'decrypt, so it must not have been applied yet',
      );

      decryptGate.complete();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      // Once the message finishes processing, the queued disconnect runs and
      // must not have been dropped, and the message handler's own state
      // write (which re-reads state rather than reusing its pre-decrypt
      // snapshot) must not race it back to "connected".
      expect(
        container.read(realtimeSyncControllerProvider).value!.status,
        RealtimeConnectionStatus.disconnected,
      );
    },
  );
}

Future<String?> _token() async => 'token';

class _FakeRealtimeSyncService extends RealtimeSyncService {
  _FakeRealtimeSyncService({this.connectGate});

  final Completer<void>? connectGate;
  final _events = StreamController<RealtimeEvent>.broadcast();
  int connectCount = 0;

  @override
  Stream<RealtimeEvent> get events => _events.stream;

  @override
  Future<void> connect({
    required String baseUrl,
    required Future<String?> Function() accessTokenProvider,
    required String currentUserId,
  }) async {
    connectCount += 1;
    _events.add(
      RealtimeEvent.connection(RealtimeConnectionStatus.connecting),
    );
    if (connectGate != null) await connectGate!.future;
    _events.add(
      RealtimeEvent.connection(RealtimeConnectionStatus.connected),
    );
  }

  @override
  Future<void> disconnect() async {
    _events.add(
      RealtimeEvent.connection(RealtimeConnectionStatus.disconnected),
    );
  }

  /// Pushes an arbitrary event as if it arrived from the server, so a test
  /// can drive events beyond the automatic connecting/connected sequence.
  void emit(RealtimeEvent event) => _events.add(event);

  Future<void> close() => _events.close();
}

/// Counts and optionally gates [getConversation] calls, so a test can
/// observe how many times an incremental sync actually ran while one is
/// deliberately held in flight.
class _CountingRemoteChatService extends RemoteChatService {
  _CountingRemoteChatService({this.gate}) : super();

  final Completer<void>? gate;
  int getConversationCalls = 0;

  @override
  Future<Map<String, int>> getUnreadCounts({
    required String baseUrl,
    required String accessToken,
  }) async => const {};

  @override
  Future<List<ChatRoom>> listRooms({
    required String baseUrl,
    required String accessToken,
  }) async => const [];

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
    getConversationCalls += 1;
    final g = gate;
    if (g != null) {
      await g.future;
    }
    return const [];
  }
}

/// Blocks [tryDecryptEnvelope] on [gate] so a test can pause message
/// processing mid-decrypt and observe state written by a concurrent event.
class _GatedMessageE2eeService extends MessageE2eeService {
  _GatedMessageE2eeService(this.gate);

  final Completer<void> gate;

  @override
  Future<String?> tryDecryptEnvelope({
    required String content,
    required bool sentByCurrentUser,
  }) async {
    await gate.future;
    return content;
  }
}
