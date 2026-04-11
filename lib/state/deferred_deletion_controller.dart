import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_controller.dart';
import 'backup_controller.dart';
import 'conversation_messages_controller.dart';
import 'user_profile_controller.dart';

enum DeferredDeletionKind { deleteAllPlanetData, deleteAccount }

extension on DeferredDeletionKind {
  String get storageValue {
    switch (this) {
      case DeferredDeletionKind.deleteAllPlanetData:
        return 'delete_all_planet_data';
      case DeferredDeletionKind.deleteAccount:
        return 'delete_account';
    }
  }
}

DeferredDeletionKind? _deferredDeletionKindFromStorageValue(String? value) {
  switch (value) {
    case 'delete_all_planet_data':
      return DeferredDeletionKind.deleteAllPlanetData;
    case 'delete_account':
      return DeferredDeletionKind.deleteAccount;
    default:
      return null;
  }
}

class DeferredDeletionState {
  const DeferredDeletionState({
    this.activeKind,
    this.executeAt,
    this.remaining = Duration.zero,
    this.isExecuting = false,
  });

  final DeferredDeletionKind? activeKind;
  final DateTime? executeAt;
  final Duration remaining;
  final bool isExecuting;

  bool get hasPending => activeKind != null && executeAt != null;
  bool get canCancel => hasPending && !isExecuting;

  DeferredDeletionState copyWith({
    DeferredDeletionKind? activeKind,
    bool clearActiveKind = false,
    DateTime? executeAt,
    bool clearExecuteAt = false,
    Duration? remaining,
    bool? isExecuting,
  }) {
    return DeferredDeletionState(
      activeKind: clearActiveKind ? null : activeKind ?? this.activeKind,
      executeAt: clearExecuteAt ? null : executeAt ?? this.executeAt,
      remaining: remaining ?? this.remaining,
      isExecuting: isExecuting ?? this.isExecuting,
    );
  }
}

final deferredDeletionNowProvider = Provider<DateTime Function()>((ref) {
  return () => DateTime.now().toUtc();
});

final deleteAllPlanetDataDelayProvider = Provider<Duration>((ref) {
  return const Duration(hours: 12);
});

final deleteAccountDelayProvider = Provider<Duration>((ref) {
  return const Duration(hours: 24);
});

final deferredDeletionControllerProvider =
    AsyncNotifierProvider<DeferredDeletionController, DeferredDeletionState>(
      DeferredDeletionController.new,
    );

class DeferredDeletionController extends AsyncNotifier<DeferredDeletionState> {
  static const _kindKey = 'deferred_deletion.kind';
  static const _executeAtKey = 'deferred_deletion.execute_at';

  Timer? _ticker;
  bool _isExecutingPending = false;

  @override
  Future<DeferredDeletionState> build() async {
    ref.onDispose(() => _ticker?.cancel());

    final prefs = await SharedPreferences.getInstance();
    final activeKind = _deferredDeletionKindFromStorageValue(
      prefs.getString(_kindKey),
    );
    final executeAtRaw = prefs.getString(_executeAtKey);
    final executeAt = executeAtRaw == null
        ? null
        : DateTime.tryParse(executeAtRaw)?.toUtc();
    if (activeKind == null || executeAt == null) {
      await _clearPersistedPending();
      return const DeferredDeletionState();
    }

    final remaining = _remainingUntil(executeAt);
    final current = DeferredDeletionState(
      activeKind: activeKind,
      executeAt: executeAt,
      remaining: remaining,
    );
    if (remaining <= Duration.zero) {
      Future<void>(() => _executePendingDeletion());
    } else {
      _startTicker();
    }
    return current;
  }

  Future<bool> scheduleDeleteAllPlanetData() async {
    return _schedule(
      DeferredDeletionKind.deleteAllPlanetData,
      ref.read(deleteAllPlanetDataDelayProvider),
    );
  }

  Future<bool> scheduleDeleteAccount() async {
    return _schedule(
      DeferredDeletionKind.deleteAccount,
      ref.read(deleteAccountDelayProvider),
    );
  }

  Future<void> cancelPendingDeletion() async {
    final current = state.value;
    if (current == null || !current.hasPending || current.isExecuting) {
      return;
    }
    _ticker?.cancel();
    _ticker = null;
    await _clearPersistedPending();
    state = const AsyncData(DeferredDeletionState());
  }

  Future<bool> _schedule(DeferredDeletionKind kind, Duration delay) async {
    final current = state.value;
    if (current == null || current.hasPending || current.isExecuting) {
      return false;
    }

    final executeAt = ref.read(deferredDeletionNowProvider)().add(delay);
    await _persistPending(kind: kind, executeAt: executeAt);
    _startTicker();
    state = AsyncData(
      DeferredDeletionState(
        activeKind: kind,
        executeAt: executeAt,
        remaining: delay,
      ),
    );
    return true;
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _refreshCountdown();
    });
  }

  void _refreshCountdown() {
    final current = state.value;
    if (current == null || !current.hasPending || current.isExecuting) {
      return;
    }

    final executeAt = current.executeAt!;
    final remaining = _remainingUntil(executeAt);
    if (remaining <= Duration.zero) {
      _executePendingDeletion();
      return;
    }

    state = AsyncData(current.copyWith(remaining: remaining));
  }

  Future<void> _executePendingDeletion() async {
    if (_isExecutingPending) {
      return;
    }
    final current = state.value;
    if (current == null || !current.hasPending) {
      return;
    }

    _isExecutingPending = true;
    _ticker?.cancel();
    _ticker = null;
    state = AsyncData(
      current.copyWith(remaining: Duration.zero, isExecuting: true),
    );
    final kind = current.activeKind!;
    await _clearPersistedPending();

    if (kind == DeferredDeletionKind.deleteAllPlanetData) {
      await _deleteAllPlanetData();
    } else {
      await _deleteAccount();
    }

    _isExecutingPending = false;
    state = const AsyncData(DeferredDeletionState());
  }

  Future<void> _deleteAllPlanetData() async {
    await ref.read(backupControllerProvider.future);
    final appState = await _currentAppState();
    final serverUrl = appState?.serverUrl?.trim();
    final accessToken = await _resolveAccessToken();

    if (serverUrl != null &&
        serverUrl.isNotEmpty &&
        accessToken != null &&
        accessToken.isNotEmpty) {
      await ref
          .read(backupControllerProvider.notifier)
          .deleteBackupData(baseUrl: serverUrl, accessToken: accessToken);
    }

    await ref.read(backupControllerProvider.notifier).deleteAllLocalData();
    _invalidatePlanetScopedData();
  }

  Future<void> _deleteAccount() async {
    await ref.read(backupControllerProvider.future);
    final appState = await _currentAppState();
    final serverUrl = appState?.serverUrl?.trim();
    final accessToken = await _resolveAccessToken();

    if (serverUrl != null &&
        serverUrl.isNotEmpty &&
        accessToken != null &&
        accessToken.isNotEmpty) {
      await ref
          .read(backupControllerProvider.notifier)
          .deleteBackupData(baseUrl: serverUrl, accessToken: accessToken);
    }

    await ref.read(backupControllerProvider.notifier).deleteAllLocalData();
    _invalidatePlanetScopedData();
    await ref.read(appControllerProvider.notifier).deleteAccount();
  }

  void _invalidatePlanetScopedData() {
    ref.invalidate(conversationSummariesProvider);
    ref.invalidate(friendIdsProvider);
    ref.invalidate(userAvatarBase64Provider);
    ref.invalidate(userDisplayNameProvider);
    ref.invalidate(userDescriptionProvider);
    ref.invalidate(friendAddedAtProvider);
    ref.invalidate(conversationMessagesProvider);
  }

  Future<AppState?> _currentAppState() async {
    try {
      return await ref.read(appControllerProvider.future);
    } catch (_) {
      return ref.read(appControllerProvider).value;
    }
  }

  Future<String?> _resolveAccessToken() async {
    final fresh = await ref
        .read(appControllerProvider.notifier)
        .ensureFreshAccessToken();
    if (fresh != null && fresh.isNotEmpty) {
      return fresh;
    }

    final fallback = (await _currentAppState())?.accessToken;
    if (fallback != null && fallback.isNotEmpty) {
      return fallback;
    }
    return null;
  }

  Duration _remainingUntil(DateTime executeAt) {
    final remaining = executeAt.difference(
      ref.read(deferredDeletionNowProvider)(),
    );
    if (remaining <= Duration.zero) {
      return Duration.zero;
    }
    return remaining;
  }

  Future<void> _persistPending({
    required DeferredDeletionKind kind,
    required DateTime executeAt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kindKey, kind.storageValue);
    await prefs.setString(_executeAtKey, executeAt.toUtc().toIso8601String());
  }

  Future<void> _clearPersistedPending() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kindKey);
    await prefs.remove(_executeAtKey);
  }
}
