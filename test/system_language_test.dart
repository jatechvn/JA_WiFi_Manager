import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:ja_wifi_manager/modules/app_config.dart';
import 'package:ja_wifi_manager/modules/i18n.dart';
import 'package:ja_wifi_manager/modules/ui/styles.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => binding.platformDispatcher.clearLocaleTestValue());

  for (final brightness in Brightness.values) {
    test('Initial theme follows $brightness and toggles without Auto', () {
      binding.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(binding.platformDispatcher.clearPlatformBrightnessTestValue);
      expect(AppConfig.systemDefaultTheme(), brightness.name);
      final notifier = ThemeNotifier(AppThemeMode.auto, brightness);
      addTearDown(notifier.dispose);
      expect(notifier.mode.code, brightness.name);
      notifier.toggle(brightness);
      expect(notifier.isDark, brightness != Brightness.dark);
      expect(notifier.mode, isNot(AppThemeMode.auto));
      notifier.toggle(brightness);
      expect(notifier.mode.code, brightness.name);
    });
  }

  for (final entry in <Locale, String>{
    const Locale('vi', 'VN'): 'vi',
    const Locale('zh', 'CN'): 'zh',
    const Locale('zh', 'TW'): 'zh',
    const Locale('en', 'US'): 'en',
    const Locale('ja', 'JP'): 'en',
    const Locale('fr', 'FR'): 'en',
  }.entries) {
    test('System locale ${entry.key} resolves to ${entry.value}', () {
      binding.platformDispatcher.localeTestValue = entry.key;
      expect(AppConfig.systemLanguageCode(), entry.value);
    });
  }

  test('Saved language takes precedence over the system language', () async {
    binding.platformDispatcher.localeTestValue = const Locale('vi', 'VN');
    await AppConfig.set('language', 'zh');
    final language = AppLanguageExt.fromCode(AppConfig.get(
      'language',
      defaultValue: AppConfig.systemLanguageCode(),
    ));
    expect(language, AppLanguage.zh);
  });
}
