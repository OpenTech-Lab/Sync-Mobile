import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/profile/profile_username_validation.dart';

void main() {
  test('allows multilingual utf8 usernames', () {
    expect(isValidProfileUsername('山田 太郎'), isTrue);
    expect(isValidProfileUsername('Марія'), isTrue);
    expect(isValidProfileUsername('مرحبا بالعالم'), isTrue);
  });

  test('rejects usernames outside allowed length range', () {
    expect(isValidProfileUsername('ab'), isFalse);
    expect(isValidProfileUsername('a' * 33), isFalse);
  });

  test('rejects control characters', () {
    expect(isValidProfileUsername('hello\nworld'), isFalse);
    expect(isValidProfileUsername('name\u0000test'), isFalse);
  });
}
