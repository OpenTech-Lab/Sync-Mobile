import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

typedef AttachmentDirectoryCandidatesResolver =
    Future<List<Directory>> Function();

class ChatAttachmentDownloadService {
  ChatAttachmentDownloadService({
    AttachmentDirectoryCandidatesResolver? directoryCandidatesResolver,
  }) : _directoryCandidatesResolver =
           directoryCandidatesResolver ?? _defaultDirectoryCandidates;

  final AttachmentDirectoryCandidatesResolver _directoryCandidatesResolver;

  Future<String> download({
    required Uint8List bytes,
    required String suggestedFileName,
  }) async {
    final fileName = _sanitizeFileName(suggestedFileName);
    final directories = await _directoryCandidatesResolver();
    Object? lastError;
    StackTrace? lastStackTrace;

    for (final directory in _uniqueDirectories(directories)) {
      try {
        final target = await _resolveUniqueFile(
          File(path.join(directory.path, fileName)),
        );
        await target.parent.create(recursive: true);
        await target.writeAsBytes(bytes, flush: true);
        return target.path;
      } catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
      }
    }

    if (lastError != null) {
      Error.throwWithStackTrace(
        lastError,
        lastStackTrace ?? StackTrace.current,
      );
    }
    throw StateError('No writable attachment directory available.');
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

  static Future<List<Directory>> _defaultDirectoryCandidates() async {
    final candidates = <Directory>[];

    if (Platform.isIOS) {
      await _addDirectoryCandidate(
        candidates,
        () async => getApplicationDocumentsDirectory(),
      );
      await _addDirectoryCandidate(
        candidates,
        () async => getTemporaryDirectory(),
      );
      return candidates;
    }

    await _addDirectoryCandidate(candidates, getDownloadsDirectory);
    await _addDirectoryCandidate(candidates, getExternalStorageDirectory);
    await _addDirectoryCandidate(
      candidates,
      () async => getApplicationDocumentsDirectory(),
    );
    await _addDirectoryCandidate(
      candidates,
      () async => getTemporaryDirectory(),
    );
    return candidates;
  }

  static Future<void> _addDirectoryCandidate(
    List<Directory> candidates,
    Future<Directory?> Function() loader,
  ) async {
    try {
      final directory = await loader();
      if (directory != null) {
        candidates.add(directory);
      }
    } catch (_) {
      // Try the next candidate.
    }
  }

  static Iterable<Directory> _uniqueDirectories(
    List<Directory> directories,
  ) sync* {
    final seenPaths = <String>{};
    for (final directory in directories) {
      final normalizedPath = directory.path.trim();
      if (normalizedPath.isEmpty || !seenPaths.add(normalizedPath)) {
        continue;
      }
      yield Directory(normalizedPath);
    }
  }
}
