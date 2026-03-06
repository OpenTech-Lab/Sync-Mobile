import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/backup_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('backup enabled preference roundtrip', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = BackupPreferences();
    const serverUrl = 'https://planet.example';
    const otherServerUrl = 'https://other.example';

    expect(await preferences.readEnabled(serverUrl), isFalse);
    expect(await preferences.readEnabled(otherServerUrl), isFalse);

    await preferences.writeEnabled(serverUrl, true);
    expect(await preferences.readEnabled(serverUrl), isTrue);
    expect(await preferences.readEnabled(otherServerUrl), isFalse);

    await preferences.writeEnabled(serverUrl, false);
    expect(await preferences.readEnabled(serverUrl), isFalse);
  });
}
