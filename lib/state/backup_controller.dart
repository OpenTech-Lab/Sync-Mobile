import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/backup_preferences.dart';
import '../services/encrypted_backup_service.dart';
import 'conversation_messages_controller.dart';

class BackupState {
  const BackupState({
    required this.enabled,
    required this.isBusy,
    required this.statusMessage,
  });

  final bool enabled;
  final bool isBusy;
  final String? statusMessage;

  BackupState copyWith({
    bool? enabled,
    bool? isBusy,
    String? statusMessage,
  }) {
    return BackupState(
      enabled: enabled ?? this.enabled,
      isBusy: isBusy ?? this.isBusy,
      statusMessage: statusMessage,
    );
  }
}

final backupControllerProvider =
    AsyncNotifierProvider<BackupController, BackupState>(BackupController.new);

class BackupController extends AsyncNotifier<BackupState> {
  final _backupPreferences = BackupPreferences();
  final _backupService = EncryptedBackupService();

  @override
  Future<BackupState> build() async {
    final enabled = await _backupPreferences.readEnabled();
    return BackupState(enabled: enabled, isBusy: false, statusMessage: null);
  }

  Future<void> setEnabled(bool enabled) async {
    final current = state.value;
    if (current == null) {
      return;
    }

    await _backupPreferences.writeEnabled(enabled);
    state = AsyncData(current.copyWith(enabled: enabled, statusMessage: null));
  }

  Future<void> createBackup() async {
    final current = state.value;
    if (current == null || !current.enabled) {
      return;
    }

    state = AsyncData(current.copyWith(isBusy: true, statusMessage: null));

    try {
      final messages = await ref.read(chatRepositoryProvider).listAllMessages();
      final backupPath = await _backupService.backupMessages(messages);
      state = AsyncData(
        current.copyWith(
          isBusy: false,
          statusMessage: 'Backup saved at $backupPath',
        ),
      );
    } catch (error) {
      state = AsyncData(
        current.copyWith(
          isBusy: false,
          statusMessage: 'Backup failed: $error',
        ),
      );
    }
  }

  Future<void> restoreBackup() async {
    final current = state.value;
    if (current == null || !current.enabled) {
      return;
    }

    state = AsyncData(current.copyWith(isBusy: true, statusMessage: null));

    try {
      final messages = await _backupService.restoreMessages();
      await ref.read(chatRepositoryProvider).replaceAllMessages(messages);

      state = AsyncData(
        current.copyWith(
          isBusy: false,
          statusMessage: 'Backup restored (${messages.length} messages).',
        ),
      );
    } catch (error) {
      state = AsyncData(
        current.copyWith(
          isBusy: false,
          statusMessage: 'Restore failed: $error',
        ),
      );
    }
  }
}
