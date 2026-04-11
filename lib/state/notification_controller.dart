import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/notification_service.dart';
import '../services/server_scope.dart';

class NotificationState {
  static const _unset = Object();

  const NotificationState({
    required this.initialized,
    required this.deviceToken,
    required this.status,
    required this.syncedServerDomain,
  });

  final bool initialized;
  final String? deviceToken;
  final String? status;
  final String? syncedServerDomain;

  bool get hasSyncedDeviceToken {
    final token = deviceToken?.trim();
    final domain = syncedServerDomain?.trim();
    return initialized &&
        token != null &&
        token.isNotEmpty &&
        domain != null &&
        domain.isNotEmpty;
  }

  bool shouldSyncDeviceToken(String? token, String serverUrl) {
    final trimmedToken = token?.trim();
    if (trimmedToken == null || trimmedToken.isEmpty) {
      return false;
    }
    final nextDomain = serverDomainKeyFromUrl(serverUrl);
    return !hasSyncedDeviceToken ||
        deviceToken != trimmedToken ||
        syncedServerDomain != nextDomain;
  }

  NotificationState copyWith({
    bool? initialized,
    Object? deviceToken = _unset,
    Object? status = _unset,
    Object? syncedServerDomain = _unset,
  }) {
    return NotificationState(
      initialized: initialized ?? this.initialized,
      deviceToken: identical(deviceToken, _unset)
          ? this.deviceToken
          : deviceToken as String?,
      status: identical(status, _unset) ? this.status : status as String?,
      syncedServerDomain: identical(syncedServerDomain, _unset)
          ? this.syncedServerDomain
          : syncedServerDomain as String?,
    );
  }
}

final notificationControllerProvider =
    AsyncNotifierProvider<NotificationController, NotificationState>(
      NotificationController.new,
    );

class NotificationController extends AsyncNotifier<NotificationState> {
  final _notificationService = NotificationService();

  @override
  Future<NotificationState> build() async {
    return const NotificationState(
      initialized: false,
      deviceToken: null,
      status: null,
      syncedServerDomain: null,
    );
  }

  Future<void> initialize({
    required String baseUrl,
    required String accessToken,
  }) async {
    final current =
        state.value ??
        const NotificationState(
          initialized: false,
          deviceToken: null,
          status: null,
          syncedServerDomain: null,
        );
    final serverDomain = serverDomainKeyFromUrl(baseUrl);

    try {
      await _notificationService.initialize();
      final token = await _notificationService.getOrCreateDeviceToken();
      final trimmedToken = token?.trim();
      if (trimmedToken == null || trimmedToken.isEmpty) {
        state = AsyncData(
          current.copyWith(
            initialized: false,
            deviceToken: null,
            status: 'Push permission granted, token pending.',
            syncedServerDomain: null,
          ),
        );
        return;
      }
      if (!current.shouldSyncDeviceToken(trimmedToken, baseUrl)) {
        return;
      }
      await _notificationService.syncTokenWithServer(
        baseUrl: baseUrl,
        accessToken: accessToken,
        token: trimmedToken,
      );

      state = AsyncData(
        current.copyWith(
          initialized: true,
          deviceToken: trimmedToken,
          status: 'Push token synced.',
          syncedServerDomain: serverDomain,
        ),
      );
    } catch (error) {
      state = AsyncData(
        current.copyWith(
          initialized: false,
          status: 'Push init failed: $error',
        ),
      );
    }
  }
}
