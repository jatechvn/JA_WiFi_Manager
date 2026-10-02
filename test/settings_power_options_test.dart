// test/settings_power_options_test.dart
// Widget tests verifying the Power & GPU Optimizer card in Settings

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_wifi_manager/modules/app_config.dart';
import 'package:ja_wifi_manager/modules/i18n.dart';
import 'package:ja_wifi_manager/modules/services/app_power_manager.dart';
import 'package:ja_wifi_manager/modules/ui/settings_tab.dart';
import 'package:ja_wifi_manager/modules/ui/styles.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('power_settings_test_');
    AppConfig.setCustomBaseDirForTesting(tempDir.path);
    AppPowerManager.instance.resetForTesting();
  });

  tearDown(() {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  Widget buildTestWidget({required Widget child}) {
    final languageNotifier = LanguageNotifier(AppLanguage.vi);
    return LanguageProvider(
      notifier: languageNotifier,
      child: MaterialApp(
        theme: buildThemeData(AppColors.dark),
        home: Scaffold(
          body: SingleChildScrollView(child: child),
        ),
      ),
    );
  }

  testWidgets('PowerOptimizerCard renders switches and segmented controls',
      (tester) async {
    await tester.pumpWidget(
      buildTestWidget(
        child: PowerOptimizerCard(onSnackbar: (_) {}),
      ),
    );

    expect(find.byType(PowerOptimizerCard), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
    expect(find.text('12 Giây (Khuyến nghị)'), findsOneWidget);
    expect(find.text('30 Giây'), findsOneWidget);
    expect(find.text('60 Giây'), findsOneWidget);
  });

  testWidgets(
      'Tapping switch toggles enableIdleSleep in AppPowerManager and AppConfig',
      (tester) async {
    String lastSnackbar = '';
    await tester.pumpWidget(
      buildTestWidget(
        child: PowerOptimizerCard(
          onSnackbar: (msg) => lastSnackbar = msg,
        ),
      ),
    );

    expect(AppPowerManager.instance.enableIdleSleep, isTrue);

    // Tap the switch to turn it off
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(AppPowerManager.instance.enableIdleSleep, isFalse);
    expect(AppConfig.get('enable_idle_sleep'), equals('false'));
    expect(lastSnackbar, contains('OFF'));

    // Tap again to turn it back on
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(AppPowerManager.instance.enableIdleSleep, isTrue);
    expect(AppConfig.get('enable_idle_sleep'), equals('true'));
    expect(lastSnackbar, contains('ON'));

    AppPowerManager.instance.cancelIdleTimerForTesting();
  });

  testWidgets(
      'Tapping 30s and 60s chips updates idleTimeoutSeconds in AppPowerManager and AppConfig',
      (tester) async {
    String lastSnackbar = '';
    await tester.pumpWidget(
      buildTestWidget(
        child: PowerOptimizerCard(
          onSnackbar: (msg) => lastSnackbar = msg,
        ),
      ),
    );

    expect(AppPowerManager.instance.idleTimeoutSeconds, equals(12));

    // Tap 30s
    await tester.tap(find.text('30 Giây'));
    await tester.pumpAndSettle();

    expect(AppPowerManager.instance.idleTimeoutSeconds, equals(30));
    expect(AppConfig.get('idle_timeout_seconds'), equals('30'));
    expect(lastSnackbar, contains('30 giây'));

    // Tap 60s
    await tester.tap(find.text('60 Giây'));
    await tester.pumpAndSettle();

    expect(AppPowerManager.instance.idleTimeoutSeconds, equals(60));
    expect(AppConfig.get('idle_timeout_seconds'), equals('60'));
    expect(lastSnackbar, contains('60 giây'));

    AppPowerManager.instance.cancelIdleTimerForTesting();
  });
}
