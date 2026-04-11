import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_profile.dart';
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
  // Keep alive so navigating away and back doesn't re-fetch and blink.
  ref.keepAlive();
  final serverUrl = ref.watch(activeServerUrlProvider);
  if (serverUrl == null) {
    return Future.value(null);
  }
  return ref
      .read(userProfilePreferencesProvider)
      .readAvatarBase64(serverUrl, userId);
});

final userDisplayNameProvider = FutureProvider.family<String?, String>((
  ref,
  userId,
) {
  ref.keepAlive();
  final serverUrl = ref.watch(activeServerUrlProvider);
  if (serverUrl == null) {
    return Future.value(null);
  }
  return ref
      .read(userProfilePreferencesProvider)
      .readDisplayName(serverUrl, userId);
});

final userDescriptionProvider = FutureProvider.family<String?, String>((
  ref,
  userId,
) {
  final serverUrl = ref.watch(activeServerUrlProvider);
  if (serverUrl == null) {
    return Future.value(null);
  }
  return ref
      .read(userProfilePreferencesProvider)
      .readDescription(serverUrl, userId);
});

final friendIdsProvider = FutureProvider<List<String>>((ref) {
  final serverUrl = ref.watch(activeServerUrlProvider);
  if (serverUrl == null) {
    return Future.value(const <String>[]);
  }
  return ref.read(userProfilePreferencesProvider).readFriendIds(serverUrl);
});

final friendTagsProvider = FutureProvider.family<List<String>, String>((
  ref,
  userId,
) {
  final serverUrl = ref.watch(activeServerUrlProvider);
  if (serverUrl == null) {
    return Future.value(const <String>[]);
  }
  return ref
      .read(userProfilePreferencesProvider)
      .readFriendTags(serverUrl, userId);
});

final friendTagCatalogProvider = FutureProvider<List<String>>((ref) {
  final serverUrl = ref.watch(activeServerUrlProvider);
  if (serverUrl == null) {
    return Future.value(const <String>[]);
  }
  return ref
      .read(userProfilePreferencesProvider)
      .readFriendTagCatalog(serverUrl);
});

final friendTagMapProvider = FutureProvider<Map<String, List<String>>>((
  ref,
) async {
  final serverUrl = ref.watch(activeServerUrlProvider);
  if (serverUrl == null) {
    return const <String, List<String>>{};
  }
  final friendIds = await ref.watch(friendIdsProvider.future);
  final preferences = ref.read(userProfilePreferencesProvider);
  final entries = await Future.wait(
    friendIds.map((userId) async {
      final tags = await preferences.readFriendTags(serverUrl, userId);
      return MapEntry(userId, tags);
    }),
  );
  return Map<String, List<String>>.fromEntries(entries);
});

final friendAddedAtProvider = FutureProvider.family<DateTime?, String>((
  ref,
  userId,
) {
  final serverUrl = ref.watch(activeServerUrlProvider);
  if (serverUrl == null) {
    return Future.value(null);
  }
  return ref
      .read(userProfilePreferencesProvider)
      .readFriendAddedAt(serverUrl, userId);
});

final myGuildSnapshotProvider = FutureProvider<UserGuildSnapshot?>((ref) async {
  final appState = await ref.watch(appControllerProvider.future);
  final serverUrl = appState.serverUrl?.trim();
  final accessToken = appState.accessToken?.trim();
  if (serverUrl == null ||
      serverUrl.isEmpty ||
      accessToken == null ||
      accessToken.isEmpty) {
    return null;
  }

  final freshToken =
      await ref.read(appControllerProvider.notifier).ensureFreshAccessToken() ??
      accessToken;
  final profile = await ref
      .read(remoteUserProfileServiceProvider)
      .getMyProfile(baseUrl: serverUrl, accessToken: freshToken);
  return profile.guild;
});

final remoteUserProfileServiceProvider = Provider<RemoteUserProfileService>((
  ref,
) {
  return RemoteUserProfileService();
});
