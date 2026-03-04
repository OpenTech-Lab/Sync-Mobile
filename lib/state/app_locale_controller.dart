import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kAppLocaleKey = 'app_locale';

enum AppLocaleOption { system, english, traditionalChinese }

extension AppLocaleOptionX on AppLocaleOption {
  Locale? toLocale() {
    return switch (this) {
      AppLocaleOption.system => null,
      AppLocaleOption.english => const Locale('en'),
      AppLocaleOption.traditionalChinese => const Locale('zh', 'TW'),
    };
  }

  String toStorageValue() {
    return switch (this) {
      AppLocaleOption.system => 'system',
      AppLocaleOption.english => 'en',
      AppLocaleOption.traditionalChinese => 'zh_TW',
    };
  }

  static AppLocaleOption fromStorageValue(String? value) {
    return switch (value) {
      'en' => AppLocaleOption.english,
      'zh_TW' => AppLocaleOption.traditionalChinese,
      _ => AppLocaleOption.system,
    };
  }
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
