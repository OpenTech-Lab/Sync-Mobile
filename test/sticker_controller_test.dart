import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/sticker.dart';
import 'package:mobile/services/sticker_cache_service.dart';
import 'package:mobile/services/sticker_service.dart';
import 'package:mobile/state/app_controller.dart';
import 'package:mobile/state/sticker_controller.dart';

class _FakeStickerService extends StickerService {
  _FakeStickerService(this._stickers, {this.shouldThrow = false});

  final List<Sticker> _stickers;
  final bool shouldThrow;

  @override
  Future<List<Sticker>> syncAll({
    required String baseUrl,
    required String accessToken,
  }) async {
    if (shouldThrow) {
      throw StateError('network down');
    }
    return _stickers;
  }
}

class _InMemoryStickerCacheService extends StickerCacheService {
  final Map<String, List<Sticker>> _cacheByServer = {};

  @override
  Future<List<Sticker>> read(String serverUrl) async =>
      _cacheByServer[serverUrl] ?? const [];

  @override
  Future<void> write(String serverUrl, List<Sticker> stickers) async {
    _cacheByServer[serverUrl] = List<Sticker>.from(stickers);
  }
}

class _DeferredStickerService extends StickerService {
  _DeferredStickerService(this._completer);

  final Completer<List<Sticker>> _completer;

  @override
  Future<List<Sticker>> syncAll({
    required String baseUrl,
    required String accessToken,
  }) {
    return _completer.future;
  }
}

void main() {
  const serverUrl = 'http://localhost:8080';

  Sticker sticker(String id) => Sticker(
        id: id,
        groupName: 'General',
        name: 's-$id',
        mimeType: 'image/png',
        contentBase64: 'aGVsbG8=',
        status: 'active',
        createdAt: DateTime.utc(2026, 3, 2),
      );

  test('sync stores remote stickers in cache and state', () async {
    final cache = _InMemoryStickerCacheService();
    final remote = _FakeStickerService([sticker('1'), sticker('2')]);

    final container = ProviderContainer(
      overrides: [
        activeServerUrlProvider.overrideWithValue(serverUrl),
        stickerCacheServiceProvider.overrideWithValue(cache),
        stickerServiceProvider.overrideWithValue(remote),
      ],
    );
    addTearDown(container.dispose);

    await container.read(stickerControllerProvider.future);
    await container.read(stickerControllerProvider.notifier).sync(
          baseUrl: 'http://localhost:8080',
          accessToken: 'token',
        );

    final state = container.read(stickerControllerProvider).value!;
    expect(state, hasLength(2));
    final cached = await cache.read(serverUrl);
    expect(cached, hasLength(2));
  });

  test('sync falls back to cached stickers on remote failure', () async {
    final cache = _InMemoryStickerCacheService();
    await cache.write(serverUrl, [sticker('cached')]);
    final remote = _FakeStickerService(const [], shouldThrow: true);

    final container = ProviderContainer(
      overrides: [
        activeServerUrlProvider.overrideWithValue(serverUrl),
        stickerCacheServiceProvider.overrideWithValue(cache),
        stickerServiceProvider.overrideWithValue(remote),
      ],
    );
    addTearDown(container.dispose);

    await container.read(stickerControllerProvider.future);
    await container.read(stickerControllerProvider.notifier).sync(
          baseUrl: 'http://localhost:8080',
          accessToken: 'token',
        );

    final state = container.read(stickerControllerProvider).value!;
    expect(state, hasLength(1));
    expect(state.first.id, 'cached');
  });

  test('sync completes after active server changes mid-flight', () async {
    const nextServerUrl = 'http://localhost:9090';
    final activeServerUrlState = StateProvider<String?>((_) => serverUrl);
    final cache = _InMemoryStickerCacheService();
    final completer = Completer<List<Sticker>>();
    final remote = _DeferredStickerService(completer);

    final container = ProviderContainer(
      overrides: [
        activeServerUrlProvider.overrideWith(
          (ref) => ref.watch(activeServerUrlState),
        ),
        stickerCacheServiceProvider.overrideWithValue(cache),
        stickerServiceProvider.overrideWithValue(remote),
      ],
    );
    addTearDown(container.dispose);

    await container.read(stickerControllerProvider.future);
    final syncFuture = container.read(stickerControllerProvider.notifier).sync(
          baseUrl: serverUrl,
          accessToken: 'token',
        );

    container.read(activeServerUrlState.notifier).state = nextServerUrl;
    await container.read(stickerControllerProvider.future);

    completer.complete([sticker('late')]);

    await expectLater(syncFuture, completes);
    expect(await cache.read(serverUrl), hasLength(1));
    expect((await cache.read(serverUrl)).first.id, 'late');
  });
}
