import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/backup_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('backup enabled preference roundtrip', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = BackupPreferences();

    expect(await preferences.readEnabled(), isFalse);

    await preferences.writeEnabled(true);
    expect(await preferences.readEnabled(), isTrue);

    await preferences.writeEnabled(false);
    expect(await preferences.readEnabled(), isFalse);
  });
}
