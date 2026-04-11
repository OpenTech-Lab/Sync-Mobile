import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/state/app_locale_controller.dart';

void main() {
  group('resolveAutomaticAppLocale', () {
    test('defaults to english when device locale is missing', () {
      expect(resolveAutomaticAppLocale(null), const Locale('en'));
    });

    test('keeps japanese for japanese system locales', () {
      expect(resolveAutomaticAppLocale(const Locale('ja', 'JP')), const Locale('ja'));
    });

    test('keeps english for english system locales', () {
      expect(resolveAutomaticAppLocale(const Locale('en', 'US')), const Locale('en'));
    });

    test('falls back to english for traditional chinese system locales', () {
      expect(
        resolveAutomaticAppLocale(const Locale('zh', 'TW')),
        const Locale('en'),
      );
    });
  });
}
