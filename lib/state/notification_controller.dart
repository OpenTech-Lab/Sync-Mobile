import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/notification_service.dart';

class NotificationState {
  static const _unset = Object();

  const NotificationState({
    required this.initialized,
    required this.deviceToken,
    required this.status,
  });

  final bool initialized;
  final String? deviceToken;
  final String? status;

  bool get hasSyncedDeviceToken {
    final token = deviceToken?.trim();
    return initialized && token != null && token.isNotEmpty;
  }

  bool shouldSyncDeviceToken(String? token) {
    final trimmedToken = token?.trim();
    if (trimmedToken == null || trimmedToken.isEmpty) {
      return false;
    }
    return !hasSyncedDeviceToken || deviceToken != trimmedToken;
  }

  NotificationState copyWith({
    bool? initialized,
    Object? deviceToken = _unset,
    Object? status = _unset,
  }) {
    return NotificationState(
      initialized: initialized ?? this.initialized,
      deviceToken: identical(deviceToken, _unset)
          ? this.deviceToken
          : deviceToken as String?,
      status: identical(status, _unset) ? this.status : status as String?,
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
        );

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
          ),
        );
        return;
      }
      if (!current.shouldSyncDeviceToken(trimmedToken)) {
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
