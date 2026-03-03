import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/notification_service.dart';

class NotificationState {
  const NotificationState({
    required this.initialized,
    required this.deviceToken,
    required this.status,
  });

  final bool initialized;
  final String? deviceToken;
  final String? status;

  NotificationState copyWith({
    bool? initialized,
    String? deviceToken,
    String? status,
  }) {
    return NotificationState(
      initialized: initialized ?? this.initialized,
      deviceToken: deviceToken ?? this.deviceToken,
      status: status,
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
    if (current.initialized) {
      return;
    }

    try {
      await _notificationService.initialize();
      final token = await _notificationService.getOrCreateDeviceToken();
      await _notificationService.syncTokenWithServer(
        baseUrl: baseUrl,
        accessToken: accessToken,
      );

      state = AsyncData(
        current.copyWith(
          initialized: true,
          deviceToken: token,
          status: token == null || token.isEmpty
              ? 'Push permission granted, token pending.'
              : 'Push token synced.',
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
