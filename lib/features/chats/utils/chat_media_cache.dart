import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/painting.dart';

import '../../../models/local_chat_message.dart';
import '../../../models/sticker.dart';

final class ParsedInlineMedia {
  const ParsedInlineMedia({
    required this.bytes,
    required this.imageProvider,
    required this.text,
    required this.suggestedFileName,
  });

  final Uint8List bytes;
  final MemoryImage imageProvider;
  final String text;
  final String suggestedFileName;
}

class ChatMediaCache {
  ChatMediaCache._();

  static const _maxInlineMediaEntries = 160;
  static const _maxStickerEntries = 160;
  static final RegExp _stickerPattern = RegExp(
    r'^\[sticker:([^:\]]+):[^\]]*\]$',
  );
  static final RegExp _mediaPattern = RegExp(
    r'\[media-data:([A-Za-z0-9+/=]+)\]',
  );
  static final LinkedHashMap<String, ParsedInlineMedia> _inlineMediaCache =
      LinkedHashMap<String, ParsedInlineMedia>();
  static final LinkedHashMap<String, MemoryImage> _stickerImageCache =
      LinkedHashMap<String, MemoryImage>();

  static String? parseStickerId(String body) {
    final match = _stickerPattern.firstMatch(body.trim());
    return match?.group(1);
  }

  static ParsedInlineMedia? parseInlineMedia(LocalChatMessage message) {
    final cacheKey =
        '${message.id}:${message.body.length}:${message.body.hashCode}';
    final cached = _take(_inlineMediaCache, cacheKey);
    if (cached != null) {
      return cached;
    }

    final match = _mediaPattern.firstMatch(message.body);
    if (match == null) {
      return null;
    }

    try {
      final bytes = base64Decode(match.group(1)!);
      final parsed = ParsedInlineMedia(
        bytes: bytes,
        imageProvider: MemoryImage(bytes),
        text: message.body.replaceFirst(match.group(0)!, '').trim(),
        suggestedFileName: _suggestedFileName(message, bytes),
      );
      _store(
        _inlineMediaCache,
        cacheKey,
        parsed,
        maxEntries: _maxInlineMediaEntries,
      );
      return parsed;
    } catch (_) {
      return null;
    }
  }

  static MemoryImage? resolveStickerImage(Sticker sticker) {
    final cacheKey =
        '${sticker.id}:${sticker.contentBase64.length}:${sticker.contentBase64.hashCode}';
    final cached = _take(_stickerImageCache, cacheKey);
    if (cached != null) {
      return cached;
    }

    try {
      final imageProvider = MemoryImage(base64Decode(sticker.contentBase64));
      _store(
        _stickerImageCache,
        cacheKey,
        imageProvider,
        maxEntries: _maxStickerEntries,
      );
      return imageProvider;
    } catch (_) {
      return null;
    }
  }

  static T? _take<T>(LinkedHashMap<String, T> cache, String key) {
    final value = cache.remove(key);
    if (value != null) {
      cache[key] = value;
    }
    return value;
  }

  static void _store<T>(
    LinkedHashMap<String, T> cache,
    String key,
    T value, {
    required int maxEntries,
  }) {
    cache[key] = value;
    while (cache.length > maxEntries) {
      cache.remove(cache.keys.first);
    }
  }

  static String _suggestedFileName(LocalChatMessage message, Uint8List bytes) {
    final extension = _inferImageFileExtension(bytes);
    final timestamp = message.createdAt.toUtc().millisecondsSinceEpoch;
    return 'sync_attachment_$timestamp.$extension';
  }

  static String _inferImageFileExtension(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A) {
      return 'png';
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'jpg';
    }
    if (bytes.length >= 6 &&
        bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x38) {
      return 'gif';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'webp';
    }
    return 'bin';
  }
}
