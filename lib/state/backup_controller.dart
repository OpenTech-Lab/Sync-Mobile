import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/backup_preferences.dart';
import '../services/encrypted_backup_service.dart';
import '../services/remote_backup_service.dart';
import 'conversation_messages_controller.dart';

class BackupState {
  const BackupState({
    required this.enabled,
    required this.isBusy,
    required this.statusMessage,
    required this.autoBackupMessageThreshold,
  });

  final bool enabled;
  final bool isBusy;
  final String? statusMessage;
  final int autoBackupMessageThreshold;

  BackupState copyWith({
    bool? enabled,
    bool? isBusy,
    String? statusMessage,
    int? autoBackupMessageThreshold,
  }) {
    return BackupState(
      enabled: enabled ?? this.enabled,
      isBusy: isBusy ?? this.isBusy,
      statusMessage: statusMessage,
      autoBackupMessageThreshold:
          autoBackupMessageThreshold ?? this.autoBackupMessageThreshold,
    );
  }
}

final backupControllerProvider =
    AsyncNotifierProvider<BackupController, BackupState>(BackupController.new);

class BackupController extends AsyncNotifier<BackupState> {
  static const Duration _autoBackupMaxInterval = Duration(hours: 24);

  final _backupPreferences = BackupPreferences();
  final _localCryptoService = EncryptedBackupService();
  final _remoteBackupService = RemoteBackupService();

  @override
  Future<BackupState> build() async {
    final enabled = await _backupPreferences.readEnabled();
    final threshold = await _backupPreferences.readAutoBackupMessageThreshold();
    return BackupState(
      enabled: enabled,
      isBusy: false,
      statusMessage: null,
      autoBackupMessageThreshold: threshold,
    );
  }

  Future<void> setEnabled(bool enabled) async {
    final current = state.value;
    if (current == null) {
      return;
    }

    await _backupPreferences.writeEnabled(enabled);
    state = AsyncData(current.copyWith(enabled: enabled, statusMessage: null));
  }

  Future<void> setAutoBackupMessageThreshold(int value) async {
    final current = state.value;
    if (current == null) {
      return;
    }
    final normalized = value.clamp(1, 1000);
    await _backupPreferences.writeAutoBackupMessageThreshold(normalized);
    state = AsyncData(
      current.copyWith(
        autoBackupMessageThreshold: normalized,
        statusMessage: null,
      ),
    );
  }

  Future<void> createBackup({
    required String baseUrl,
    required String accessToken,
  }) async {
    final current = state.value;
    if (current == null || !current.enabled) {
      return;
    }

    state = AsyncData(current.copyWith(isBusy: true, statusMessage: null));

    try {
      final messages = await ref.read(chatRepositoryProvider).listAllMessages();
      final keyBytes = await _localCryptoService.readOrCreateSecretKeyBytes();
      await _remoteBackupService.uploadBackup(
        baseUrl: baseUrl,
        accessToken: accessToken,
        messages: messages,
        keyBytes: keyBytes,
      );
      state = AsyncData(
        current.copyWith(
          isBusy: false,
          statusMessage: 'Encrypted backup uploaded to planet server.',
        ),
      );
      await _backupPreferences.writeLastBackupMetadata(
        backedAt: DateTime.now().toUtc(),
        messageCount: messages.length,
      );
    } catch (error) {
      state = AsyncData(
        current.copyWith(isBusy: false, statusMessage: 'Backup failed: $error'),
      );
    }
  }

  Future<void> maybeAutoBackup({
    required String baseUrl,
    required String accessToken,
  }) async {
    final current = state.value;
    if (current == null || !current.enabled || current.isBusy) {
      return;
    }

    final messages = await ref.read(chatRepositoryProvider).listAllMessages();
    final currentCount = messages.length;
    final lastCount = await _backupPreferences.readLastBackedMessageCount();
    final lastBackupAt = await _backupPreferences.readLastBackupAt();
    final unbackedCount = (currentCount - lastCount).clamp(0, currentCount);

    final dueByCount = unbackedCount >= current.autoBackupMessageThreshold;
    final dueByTime =
        lastBackupAt == null ||
        DateTime.now().toUtc().difference(lastBackupAt) >=
            _autoBackupMaxInterval;

    if (!dueByCount && !dueByTime) {
      return;
    }

    state = AsyncData(current.copyWith(isBusy: true, statusMessage: null));
    try {
      final keyBytes = await _localCryptoService.readOrCreateSecretKeyBytes();
      await _remoteBackupService.uploadBackup(
        baseUrl: baseUrl,
        accessToken: accessToken,
        messages: messages,
        keyBytes: keyBytes,
      );
      await _backupPreferences.writeLastBackupMetadata(
        backedAt: DateTime.now().toUtc(),
        messageCount: currentCount,
      );
      state = AsyncData(
        current.copyWith(
          isBusy: false,
          statusMessage: 'Auto backup uploaded to planet server.',
        ),
      );
    } catch (error) {
      state = AsyncData(
        current.copyWith(
          isBusy: false,
          statusMessage: 'Auto backup failed: $error',
        ),
      );
    }
  }

  Future<void> restoreBackup({
    required String baseUrl,
    required String accessToken,
  }) async {
    final current = state.value;
    if (current == null || !current.enabled) {
      return;
    }

    state = AsyncData(current.copyWith(isBusy: true, statusMessage: null));

    try {
      final keyBytes = await _localCryptoService.readOrCreateSecretKeyBytes();
      final messages = await _remoteBackupService.restoreBackup(
        baseUrl: baseUrl,
        accessToken: accessToken,
        keyBytes: keyBytes,
      );
      await ref.read(chatRepositoryProvider).replaceAllMessages(messages);
      await _backupPreferences.writeLastBackupMetadata(
        backedAt: DateTime.now().toUtc(),
        messageCount: messages.length,
      );

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

  Future<void> deleteBackupData({
    required String baseUrl,
    required String accessToken,
  }) async {
    final current = state.value;
    if (current == null || !current.enabled) {
      return;
    }

    state = AsyncData(current.copyWith(isBusy: true, statusMessage: null));

    try {
      await _remoteBackupService.deleteBackup(
        baseUrl: baseUrl,
        accessToken: accessToken,
      );
      await _backupPreferences.clearLastBackupMetadata();
      state = AsyncData(
        current.copyWith(
          isBusy: false,
          statusMessage: 'Server backup deleted.',
        ),
      );
    } catch (error) {
      state = AsyncData(
        current.copyWith(
          isBusy: false,
          statusMessage: 'Delete backup failed: $error',
        ),
      );
    }
  }

  Future<void> deleteLocalChatData() async {
    final current = state.value;
    if (current == null) {
      return;
    }

    state = AsyncData(current.copyWith(isBusy: true, statusMessage: null));

    try {
      await ref.read(chatRepositoryProvider).replaceAllMessages(const []);
      ref.invalidate(conversationSummariesProvider);
      await _backupPreferences.writeLastBackupMetadata(
        backedAt: DateTime.now().toUtc(),
        messageCount: 0,
      );
      state = AsyncData(
        current.copyWith(
          isBusy: false,
          statusMessage: 'All local chat data deleted on this device.',
        ),
      );
    } catch (error) {
      state = AsyncData(
        current.copyWith(
          isBusy: false,
          statusMessage: 'Delete local chat data failed: $error',
        ),
      );
    }
  }

  Future<void> deleteAllLocalData() async {
    final current = state.value;
    if (current == null) {
      return;
    }

    state = AsyncData(current.copyWith(isBusy: true, statusMessage: null));

    try {
      // Clear all local chat messages
      await ref.read(chatRepositoryProvider).replaceAllMessages(const []);
      ref.invalidate(conversationSummariesProvider);

      // Delete local encrypted backup file
      await _localCryptoService.deleteBackup();

      // Clear all SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      state = AsyncData(
        current.copyWith(
          isBusy: false,
          statusMessage: 'All local app data deleted on this device.',
        ),
      );
    } catch (error) {
      state = AsyncData(
        current.copyWith(
          isBusy: false,
          statusMessage: 'Delete all local data failed: $error',
        ),
      );
    }
  }
}
