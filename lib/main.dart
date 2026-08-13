// lib/main.dart
// Program entry point for JA WiFi Hotspot Guard
// Transparent blur window with Light/Dark/Auto theme + multi-language support

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'modules/constants.dart';
import 'modules/logger_config.dart';
import 'modules/logic.dart';
import 'modules/app_config.dart';
import 'modules/i18n.dart';
import 'modules/ui/styles.dart';
import 'modules/ui/main_window.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize daily logging
  setupLogger();

  // Load config from config.ini (language preference, theme preference, transparency settings)
  await AppConfig.initialize();

  // Initialize window manager
  await windowManager.ensureInitialized();

  // Initialize transparent blur core
  await Window.initialize();

  // Restore saved theme to select solid background color if transparency is disabled
  final initialThemeStr = AppConfig.get('theme', defaultValue: 'dark');
  final isDark = initialThemeStr == 'dark' ||
      (initialThemeStr == 'auto' &&
          WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.dark);
  final windowBgColor = AppConfig.enableTransparency
      ? Colors.transparent
      : (isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC));

  // Configure window options
  final windowOptions = WindowOptions(
    size: const Size(1280, 720),
    minimumSize: const Size(960, 540),
    title: '$appName  v$appVersion',
    backgroundColor: windowBgColor,
    titleBarStyle: TitleBarStyle.normal,
  );

  final startMinimized = args.contains('--minimized') ||
      AppConfig.get('start_minimized', defaultValue: 'false') == 'true';

  await windowManager.setPreventClose(true);
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    if (!startMinimized) {
      await windowManager.show();
      await windowManager.focus();
    } else {
      await windowManager.hide();
    }
    try {
      await windowManager.setAlignment(Alignment.center);
    } catch (_) {}
  });

  // Apply acrylic / mica transparent background blur
  if (AppConfig.enableTransparency) {
    try {
      if (isWindows11) {
        await Window.setEffect(
          effect: WindowEffect.acrylic,
          color: const Color(0x00000000), // fully transparent base
        );
      } else {
        await Window.setEffect(
          effect: WindowEffect.aero,
          color: const Color(0x00000000),
        );
      }
    } catch (_) {
      try {
        await Window.setEffect(
          effect: WindowEffect.mica,
          color: const Color(0x00000000),
        );
      } catch (_) {}
    }
  } else {
    try {
      await Window.setEffect(
        effect: WindowEffect.disabled,
      );
    } catch (_) {}
  }

  // Initialize business logic
  final wifiLogic = WifiGuardLogic();

  // Check if running as administrator
  // (Firewall and ARP commands require administrator privileges)
  final isAdmin = await wifiLogic.isAdmin();
  if (!isAdmin) {
    await wifiLogic.elevateAdmin();
    exit(0);
  }

  // Restore saved language and theme
  final savedLang =
      AppLanguageExt.fromCode(AppConfig.get('language', defaultValue: 'en'));
  final savedThemeStr = AppConfig.get('theme', defaultValue: 'dark');
  final savedThemeMode = AppThemeModeExt.fromCode(savedThemeStr);

  runApp(JaWifiManagerApp(
    logic: wifiLogic,
    initialLanguage: savedLang,
    initialThemeMode: savedThemeMode,
  ));
}

class JaWifiManagerApp extends StatefulWidget {
  final WifiGuardLogic logic;
  final AppLanguage initialLanguage;
  final AppThemeMode initialThemeMode;

  const JaWifiManagerApp({
    super.key,
    required this.logic,
    required this.initialLanguage,
    required this.initialThemeMode,
  });

  @override
  State<JaWifiManagerApp> createState() => _JaWifiManagerAppState();
}

class _JaWifiManagerAppState extends State<JaWifiManagerApp> {
  late final ThemeNotifier _themeNotifier;
  late final LanguageNotifier _languageNotifier;

  @override
  void initState() {
    super.initState();
    _languageNotifier = LanguageNotifier(widget.initialLanguage);

    final platformBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    _themeNotifier = ThemeNotifier(widget.initialThemeMode, platformBrightness);
  }

  @override
  void dispose() {
    _themeNotifier.dispose();
    _languageNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LanguageProvider(
      notifier: _languageNotifier,
      child: ListenableBuilder(
        listenable: Listenable.merge([_themeNotifier, _languageNotifier]),
        builder: (context, _) {
          return MaterialApp(
            title: '$appName  v$appVersion',
            debugShowCheckedModeBanner: false,
            theme: buildThemeData(_themeNotifier.colors),
            home: ThemeReveal(
              themeNotifier: _themeNotifier,
              child: MainWindow(
                logic: widget.logic,
                themeNotifier: _themeNotifier,
                languageNotifier: _languageNotifier,
              ),
            ),
          );
        },
      ),
    );
  }
}
