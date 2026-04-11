import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/remote_chat_service.dart';
import 'package:mobile/state/conversation_messages_controller.dart';
import 'package:mobile/state/unread_counts_controller.dart';

class _FakeRemoteChatService extends RemoteChatService {
  _FakeRemoteChatService(this._counts) : super();

  final Map<String, int> _counts;

  @override
  Future<Map<String, int>> getUnreadCounts({
    required String baseUrl,
    required String accessToken,
  }) async {
    return _counts;
  }
}

void main() {
  test('refresh loads unread counts from remote service', () async {
    final remote = _FakeRemoteChatService({
      '11111111-1111-1111-1111-111111111111': 3,
      '22222222-2222-2222-2222-222222222222': 1,
    });

    final container = ProviderContainer(
      overrides: [remoteChatServiceProvider.overrideWithValue(remote)],
    );
    addTearDown(container.dispose);

    await container.read(unreadCountsProvider.future);
    await container.read(unreadCountsProvider.notifier).refresh(
          baseUrl: 'http://localhost:8080',
          accessToken: 'token',
        );

    final counts = container.read(unreadCountsProvider).value!;
    expect(counts['11111111-1111-1111-1111-111111111111'], 3);
    expect(counts['22222222-2222-2222-2222-222222222222'], 1);
  });

  test('clearForPartner removes partner unread badge count', () async {
    final remote = _FakeRemoteChatService({
      '11111111-1111-1111-1111-111111111111': 2,
    });

    final container = ProviderContainer(
      overrides: [remoteChatServiceProvider.overrideWithValue(remote)],
    );
    addTearDown(container.dispose);

    await container.read(unreadCountsProvider.future);
    await container.read(unreadCountsProvider.notifier).refresh(
          baseUrl: 'http://localhost:8080',
          accessToken: 'token',
        );

    container
        .read(unreadCountsProvider.notifier)
        .clearForPartner('11111111-1111-1111-1111-111111111111');

    final counts = container.read(unreadCountsProvider).value!;
    expect(counts.containsKey('11111111-1111-1111-1111-111111111111'), isFalse);
  });
}
