import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/sticker.dart';
import '../services/sticker_cache_service.dart';
import '../services/sticker_service.dart';

final stickerServiceProvider = Provider<StickerService>((ref) {
  return StickerService();
});

final stickerCacheServiceProvider = Provider<StickerCacheService>((ref) {
  return StickerCacheService();
});

final stickerControllerProvider =
    AsyncNotifierProvider<StickerController, List<Sticker>>(
  StickerController.new,
);

class StickerController extends AsyncNotifier<List<Sticker>> {
  StickerService get _service => ref.read(stickerServiceProvider);
  StickerCacheService get _cache => ref.read(stickerCacheServiceProvider);

  @override
  Future<List<Sticker>> build() {
    return _cache.read();
  }

  Future<void> sync({
    required String baseUrl,
    required String accessToken,
  }) async {
    try {
      final stickers = await _service.syncAll(
        baseUrl: baseUrl,
        accessToken: accessToken,
      );
      await _cache.write(stickers);
      state = AsyncData(stickers);
    } catch (_) {
      final cached = await _cache.read();
      state = AsyncData(cached);
    }
  }
}
