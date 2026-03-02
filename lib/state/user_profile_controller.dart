import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/user_profile_preferences.dart';

final userProfilePreferencesProvider = Provider<UserProfilePreferences>((ref) {
  return UserProfilePreferences();
});

final userAvatarBase64Provider = FutureProvider.family<String?, String>(
  (ref, userId) {
    return ref.read(userProfilePreferencesProvider).readAvatarBase64(userId);
  },
);
