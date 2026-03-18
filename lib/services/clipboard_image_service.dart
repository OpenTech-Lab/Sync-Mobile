import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ClipboardImageService {
  ClipboardImageService._();

  static const MethodChannel _channel = MethodChannel('sync.clipboard');

  static Future<void> copyPng({
    required Uint8List pngBytes,
    required String fallbackText,
  }) async {
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _channel.invokeMethod<void>('copyPngToClipboard', pngBytes);
        return;
      } on MissingPluginException {
        // Fall through to text copy when the native bridge is unavailable.
      } on PlatformException {
        // Fall through to text copy when the native bridge rejects the image.
      }
    }

    await Clipboard.setData(ClipboardData(text: fallbackText));
  }
}
