import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/state/notification_controller.dart';

void main() {
  test('hasSyncedDeviceToken is false while token is still pending', () {
    const state = NotificationState(
      initialized: true,
      deviceToken: null,
      status: 'Push permission granted, token pending.',
    );

    expect(state.hasSyncedDeviceToken, isFalse);
  });

  test('hasSyncedDeviceToken is true once token is stored', () {
    const state = NotificationState(
      initialized: true,
      deviceToken: 'abc123',
      status: 'Push token synced.',
    );

    expect(state.hasSyncedDeviceToken, isTrue);
  });

  test('copyWith can clear a previously stored token', () {
    const initial = NotificationState(
      initialized: true,
      deviceToken: 'abc123',
      status: 'Push token synced.',
    );

    final updated = initial.copyWith(
      initialized: false,
      deviceToken: null,
      status: 'Push permission granted, token pending.',
    );

    expect(updated.initialized, isFalse);
    expect(updated.deviceToken, isNull);
    expect(updated.status, 'Push permission granted, token pending.');
    expect(updated.hasSyncedDeviceToken, isFalse);
  });

  test('shouldSyncDeviceToken is false for the already-synced token', () {
    const state = NotificationState(
      initialized: true,
      deviceToken: 'abc123',
      status: 'Push token synced.',
    );

    expect(state.shouldSyncDeviceToken('abc123'), isFalse);
  });

  test('shouldSyncDeviceToken is true when APNs rotates the token', () {
    const state = NotificationState(
      initialized: true,
      deviceToken: 'abc123',
      status: 'Push token synced.',
    );

    expect(state.shouldSyncDeviceToken('def456'), isTrue);
  });
}
