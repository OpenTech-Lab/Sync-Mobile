import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_controller.dart';
import '../services/remote_user_profile_service.dart';
import '../services/user_profile_preferences.dart';

final userProfilePreferencesProvider = Provider<UserProfilePreferences>((ref) {
  return UserProfilePreferences();
});

final userAvatarBase64Provider = FutureProvider.family<String?, String>((
  ref,
  userId,
) {
  final serverUrl = ref.watch(activeServerUrlProvider);
  if (serverUrl == null) {
    return Future.value(null);
  }
  return ref.read(userProfilePreferencesProvider).readAvatarBase64(
        serverUrl,
        userId,
      );
});

final userDisplayNameProvider = FutureProvider.family<String?, String>((
  ref,
  userId,
) {
  final serverUrl = ref.watch(activeServerUrlProvider);
  if (serverUrl == null) {
    return Future.value(null);
  }
  return ref.read(userProfilePreferencesProvider).readDisplayName(
        serverUrl,
        userId,
      );
});

final userDescriptionProvider = FutureProvider.family<String?, String>((
  ref,
  userId,
) {
  final serverUrl = ref.watch(activeServerUrlProvider);
  if (serverUrl == null) {
    return Future.value(null);
  }
  return ref.read(userProfilePreferencesProvider).readDescription(
        serverUrl,
        userId,
      );
});

final friendIdsProvider = FutureProvider<List<String>>((ref) {
  final serverUrl = ref.watch(activeServerUrlProvider);
  if (serverUrl == null) {
    return Future.value(const <String>[]);
  }
  return ref.read(userProfilePreferencesProvider).readFriendIds(serverUrl);
});

final friendAddedAtProvider = FutureProvider.family<DateTime?, String>((
  ref,
  userId,
) {
  final serverUrl = ref.watch(activeServerUrlProvider);
  if (serverUrl == null) {
    return Future.value(null);
  }
  return ref.read(userProfilePreferencesProvider).readFriendAddedAt(
        serverUrl,
        userId,
      );
});

final remoteUserProfileServiceProvider = Provider<RemoteUserProfileService>((
  ref,
) {
  return RemoteUserProfileService();
});
