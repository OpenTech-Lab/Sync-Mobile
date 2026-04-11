import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/jwt_service.dart';

void main() {
  const jwtService = JwtService();

  test('tryReadUserId extracts sub claim from JWT payload', () {
    final header = base64Url.encode(utf8.encode('{"alg":"HS256","typ":"JWT"}'));
    final payload = base64Url.encode(
      utf8.encode('{"sub":"11111111-1111-1111-1111-111111111111"}'),
    );
    const signature = 'signature';
    final token = '$header.$payload.$signature';

    final userId = jwtService.tryReadUserId(token);
    expect(userId, '11111111-1111-1111-1111-111111111111');
  });

  test('tryReadUserId returns null for malformed token', () {
    final userId = jwtService.tryReadUserId('bad-token');
    expect(userId, isNull);
  });
}
