import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kAppLocaleKey = 'app_locale';
const _kSystemFallbackLocale = Locale('en');
const _kAutomaticSupportedLocales = <Locale>[Locale('en'), Locale('ja'), Locale('zh', 'TW')];

enum AppLocaleOption {
  system,
  english,
  japanese,
  traditionalChinese,
}

extension AppLocaleOptionX on AppLocaleOption {
  Locale? toLocale() {
    return switch (this) {
      AppLocaleOption.system => null,
      AppLocaleOption.english => const Locale('en'),
      AppLocaleOption.japanese => const Locale('ja'),
      AppLocaleOption.traditionalChinese => const Locale('zh', 'TW'),
    };
  }

  String toStorageValue() {
    return switch (this) {
      AppLocaleOption.system => 'system',
      AppLocaleOption.english => 'en',
      AppLocaleOption.japanese => 'ja',
      AppLocaleOption.traditionalChinese => 'zh_TW',
    };
  }

  static AppLocaleOption fromStorageValue(String? value) {
    return switch (value) {
      'en' => AppLocaleOption.english,
      'ja' => AppLocaleOption.japanese,
      'zh_TW' => AppLocaleOption.traditionalChinese,
      _ => AppLocaleOption.system,
    };
  }
}

Locale resolveAutomaticAppLocale(Locale? deviceLocale) {
  if (deviceLocale == null) {
    return _kSystemFallbackLocale;
  }

  for (final locale in _kAutomaticSupportedLocales) {
    if (locale.languageCode == deviceLocale.languageCode &&
        (locale.countryCode == null ||
            locale.countryCode == deviceLocale.countryCode)) {
      return locale;
    }
  }

  return _kSystemFallbackLocale;
}

class AppLocaleNotifier extends Notifier<AppLocaleOption> {
  @override
  AppLocaleOption build() {
    _load();
    return AppLocaleOption.system;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_kAppLocaleKey);
    final option = AppLocaleOptionX.fromStorageValue(stored);
    if (option != state) {
      state = option;
    }
  }

  Future<void> setOption(AppLocaleOption option) async {
    state = option;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAppLocaleKey, option.toStorageValue());
  }
}

final appLocaleProvider = NotifierProvider<AppLocaleNotifier, AppLocaleOption>(
  AppLocaleNotifier.new,
);
