import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/remote_user_profile_service.dart';
import '../services/user_profile_preferences.dart';

final userProfilePreferencesProvider = Provider<UserProfilePreferences>((ref) {
  return UserProfilePreferences();
});

final userAvatarBase64Provider = FutureProvider.family<String?, String>((
  ref,
  userId,
) {
  return ref.read(userProfilePreferencesProvider).readAvatarBase64(userId);
});

final userDisplayNameProvider = FutureProvider.family<String?, String>((
  ref,
  userId,
) {
  return ref.read(userProfilePreferencesProvider).readDisplayName(userId);
});

final userDescriptionProvider = FutureProvider.family<String?, String>((
  ref,
  userId,
) {
  return ref.read(userProfilePreferencesProvider).readDescription(userId);
});

final friendIdsProvider = FutureProvider<List<String>>((ref) {
  return ref.read(userProfilePreferencesProvider).readFriendIds();
});

final friendAddedAtProvider = FutureProvider.family<DateTime?, String>((
  ref,
  userId,
) {
  return ref.read(userProfilePreferencesProvider).readFriendAddedAt(userId);
});

final remoteUserProfileServiceProvider = Provider<RemoteUserProfileService>((
  ref,
) {
  return RemoteUserProfileService();
});
