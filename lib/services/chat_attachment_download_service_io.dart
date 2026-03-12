import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class ChatAttachmentDownloadService {
  Future<String> download({
    required Uint8List bytes,
    required String suggestedFileName,
  }) async {
    final directory = await _resolveDirectory();
    final fileName = _sanitizeFileName(suggestedFileName);
    final target = await _resolveUniqueFile(
      File(path.join(directory.path, fileName)),
    );
    await target.parent.create(recursive: true);
    await target.writeAsBytes(bytes, flush: true);
    return target.path;
  }

  Future<Directory> _resolveDirectory() async {
    try {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) {
        return downloads;
      }
    } catch (_) {
      // Fallback below.
    }
    try {
      final external = await getExternalStorageDirectory();
      if (external != null) {
        return external;
      }
    } catch (_) {
      // Fallback below.
    }
    return getApplicationDocumentsDirectory();
  }

  Future<File> _resolveUniqueFile(File file) async {
    if (!await file.exists()) {
      return file;
    }

    final directory = file.parent.path;
    final extension = path.extension(file.path);
    final baseName = path.basenameWithoutExtension(file.path);

    for (var index = 1; index < 1000; index += 1) {
      final candidate = File(
        path.join(directory, '$baseName ($index)$extension'),
      );
      if (!await candidate.exists()) {
        return candidate;
      }
    }

    final fallback =
        '$baseName-${DateTime.now().toUtc().millisecondsSinceEpoch}$extension';
    return File(path.join(directory, fallback));
  }

  String _sanitizeFileName(String raw) {
    final trimmed = raw.trim();
    final normalized = trimmed.isEmpty ? 'attachment.bin' : trimmed;
    return normalized.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }
}
