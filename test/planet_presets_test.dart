import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/constants/planet_presets.dart';

void main() {
  group('resolvePlanetName', () {
    test('prefers the health instance name for local IP servers', () {
      final label = resolvePlanetName(
        serverUrl: 'http://192.168.11.9',
        instanceName: 'Mars Base',
        fallbackName: 'Unknown planet',
      );

      expect(label, 'Mars Base');
    });

    test(
      'falls back to official preset names when health name is unavailable',
      () {
        final label = resolvePlanetName(
          serverUrl: 'https://sync.icyanstudio.net/',
          fallbackName: 'Unknown planet',
        );

        expect(label, 'SYNC');
      },
    );

    test(
      'uses the provided fallback when there is no health name or preset',
      () {
        final label = resolvePlanetName(
          serverUrl: 'http://192.168.11.9',
          fallbackName: 'Unknown planet',
        );

        expect(label, 'Unknown planet');
      },
    );
  });
}
