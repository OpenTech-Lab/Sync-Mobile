import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/realtime_event.dart';
import 'package:mobile/services/realtime_sync_service.dart';
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

  Future<void> close() => _events.close();
}
