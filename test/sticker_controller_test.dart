import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/sticker.dart';
import 'package:mobile/services/sticker_cache_service.dart';
import 'package:mobile/services/sticker_service.dart';
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
  List<Sticker> _cache = const [];

  @override
  Future<List<Sticker>> read() async => _cache;

  @override
  Future<void> write(List<Sticker> stickers) async {
    _cache = List<Sticker>.from(stickers);
  }
}

void main() {
  Sticker sticker(String id) => Sticker(
        id: id,
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
    final cached = await cache.read();
    expect(cached, hasLength(2));
  });

  test('sync falls back to cached stickers on remote failure', () async {
    final cache = _InMemoryStickerCacheService();
    await cache.write([sticker('cached')]);
    final remote = _FakeStickerService(const [], shouldThrow: true);

    final container = ProviderContainer(
      overrides: [
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
}
