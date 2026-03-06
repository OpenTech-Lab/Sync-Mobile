import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/sticker.dart';
import '../services/sticker_cache_service.dart';
import '../services/sticker_service.dart';
import 'app_controller.dart';

typedef _StickerByIdArg = ({
  String id,
  String baseUrl,
  String accessToken,
});

final stickerByIdProvider =
    FutureProvider.family<Sticker?, _StickerByIdArg>((ref, arg) async {
  final service = ref.read(stickerServiceProvider);
  return service.fetchById(
    baseUrl: arg.baseUrl,
    accessToken: arg.accessToken,
    id: arg.id,
  );
});

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
    final serverUrl = ref.watch(activeServerUrlProvider);
    if (serverUrl == null) {
      return Future.value(const <Sticker>[]);
    }
    return _cache.read(serverUrl);
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
      await _cache.write(baseUrl, stickers);
      state = AsyncData(stickers);
    } catch (_) {
      final cached = await _cache.read(baseUrl);
      state = AsyncData(cached);
    }
  }

  Future<void> downloadToLocal(Sticker sticker) async {
    final serverUrl = ref.read(activeServerUrlProvider);
    if (serverUrl == null) {
      return;
    }
    final current = await _cache.read(serverUrl);
    final next = <Sticker>[
      for (final item in current)
        if (item.id != sticker.id) item,
      sticker,
    ];
    await _cache.write(serverUrl, next);
    state = AsyncData(next);
  }
}
