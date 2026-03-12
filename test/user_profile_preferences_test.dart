import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/user_profile_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('profile values stay isolated per server domain', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = UserProfilePreferences();
    const userId = 'user-123';
    const serverA = 'https://planet-a.example';
    const serverB = 'https://planet-b.example';

    await preferences.writeDisplayName(serverA, userId, 'Planet A User');
    await preferences.writeDisplayName(serverB, userId, 'Planet B User');
    await preferences.writeAvatarBase64(serverA, userId, 'avatar-a');
    await preferences.writeAvatarBase64(serverB, userId, 'avatar-b');
    await preferences.addFriendId(serverA, 'friend-a');
    await preferences.addFriendId(serverB, 'friend-b');

    expect(await preferences.readDisplayName(serverA, userId), 'Planet A User');
    expect(await preferences.readDisplayName(serverB, userId), 'Planet B User');
    expect(await preferences.readAvatarBase64(serverA, userId), 'avatar-a');
    expect(await preferences.readAvatarBase64(serverB, userId), 'avatar-b');
    expect(await preferences.readFriendIds(serverA), ['friend-a']);
    expect(await preferences.readFriendIds(serverB), ['friend-b']);
  });

  test(
    'friend tags stay reusable across friends while assignments stay local',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = UserProfilePreferences();
      const serverUrl = 'https://planet-a.example';

      await preferences.writeFriendTags(serverUrl, 'friend-a', [
        'Work',
        ' VIP ',
      ]);
      await preferences.writeFriendTags(serverUrl, 'friend-b', [
        'work',
        'Family',
      ]);

      expect(await preferences.readFriendTags(serverUrl, 'friend-a'), [
        'VIP',
        'Work',
      ]);
      expect(await preferences.readFriendTags(serverUrl, 'friend-b'), [
        'Family',
        'Work',
      ]);
      expect(await preferences.readFriendTagCatalog(serverUrl), [
        'Family',
        'VIP',
        'Work',
      ]);

      await preferences.removeFriendId(serverUrl, 'friend-b');

      expect(await preferences.readFriendTags(serverUrl, 'friend-b'), isEmpty);
      expect(await preferences.readFriendTagCatalog(serverUrl), [
        'Family',
        'VIP',
        'Work',
      ]);
    },
  );
}
