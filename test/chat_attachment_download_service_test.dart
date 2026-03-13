import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/chat_attachment_download_service_io.dart';
import 'package:path/path.dart' as path;

void main() {
  test('download falls back to the next writable directory', () async {
    final root = await Directory.systemTemp.createTemp(
      'chat_attachment_download_service_test',
    );

    try {
      final blockedPath = path.join(root.path, 'blocked');
      await File(blockedPath).writeAsString('not a directory');
      final writableDirectory = Directory(path.join(root.path, 'writable'));

      final service = ChatAttachmentDownloadService(
        directoryCandidatesResolver: () async => [
          Directory(blockedPath),
          writableDirectory,
        ],
      );

      final savedPath = await service.download(
        bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
        suggestedFileName: 'planet.png',
      );

      expect(savedPath, path.join(writableDirectory.path, 'planet.png'));
      expect(await File(savedPath).readAsBytes(), <int>[1, 2, 3, 4]);
    } finally {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    }
  });
}
