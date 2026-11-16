// test/ics_progress_banner_test.dart
// Tests for ICS interactive render lease, scan contention deferral, and inline Bento progress banner.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_wifi_manager/modules/app_config.dart';
import 'package:ja_wifi_manager/modules/i18n.dart';
import 'package:ja_wifi_manager/modules/logic.dart';
import 'package:ja_wifi_manager/modules/services/app_power_manager.dart';
import 'package:ja_wifi_manager/modules/services/power_widgets_binding.dart';
import 'package:ja_wifi_manager/modules/ui/hotspot_tab.dart';
import 'package:ja_wifi_manager/modules/ui/monitor_tab.dart';
import 'package:ja_wifi_manager/modules/ui/styles.dart';

class _PowerLeaseTestBinding extends AutomatedTestWidgetsFlutterBinding
    with PowerFramePolicy {}

void main() {
  final binding = _PowerLeaseTestBinding();
  final power = AppPowerManager.instance;
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('ics_progress_banner_');
    AppConfig.setCustomBaseDirForTesting(tempDir.path);
    power.resetForTesting();
  });

  tearDown(() {
    power.resetForTesting();
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  Widget wrapWithApp(Widget child, {AppLanguage language = AppLanguage.vi}) {
    final languageNotifier = LanguageNotifier(language);
    return LanguageProvider(
      notifier: languageNotifier,
      child: MaterialApp(
        theme: buildThemeData(AppColors.dark),
        home: Scaffold(
          body: SizedBox(
            width: 1280,
            height: 720,
            child: child,
          ),
        ),
      ),
    );
  }

  group('Fix ICS anti-freeze engine guarantees', () {
    testWidgets(
        'AppPowerManager keeps visible indicator frames enabled during active ICS operation even on blur',
        (tester) async {
      await tester.pumpWidget(const SizedBox.shrink());

      // Normal blur pauses rendering
      power.onWindowBlur();
      expect(power.shouldAnimateIndicators, isFalse);
      expect(binding.framesEnabled, isFalse);

      // Starting Fix ICS keeps visible window rendering smooth even if focus momentarily flickers
      power.beginInteractiveOperation();
      expect(power.shouldAnimateIndicators, isTrue);
      expect(binding.framesEnabled, isTrue);

      // Ending Fix ICS restores paused state when window is blurred
      power.endInteractiveOperation();
      expect(power.shouldAnimateIndicators, isFalse);
      expect(binding.framesEnabled, isFalse);

      // Tray hide / minimize ALWAYS gates rendering even if an operation is running
      power.beginInteractiveOperation();
      power.onWindowVisibilityChanged(false);
      expect(power.shouldAnimateIndicators, isFalse);
      expect(binding.framesEnabled, isFalse);
      power.endInteractiveOperation();
    });

    test('scanConnectedClients skips WMI/ARP PowerShell while isHotspotBusy',
        () async {
      final repairStarted = Completer<void>();
      final repairCompleter = Completer<Map<String, dynamic>>();
      final psCommands = <String>[];
      final logic = WifiGuardLogic(
        nativeCommand: (_, args) async {
          psCommands.add(args.join(' '));
          return ProcessResult(1, 0, '', '');
        },
        nativeIcsRepair: (
            {timeout = const Duration(seconds: 60), onProgressStep}) {
          onProgressStep?.call('Stop SharedAccess');
          if (!repairStarted.isCompleted) {
            repairStarted.complete();
          }
          return repairCompleter.future;
        },
      );

      final repairFuture = logic.repairIcsService();
      await repairStarted.future;
      expect(logic.isHotspotBusy, isTrue);
      expect(logic.hotspotBusyStatus?.phaseKey, 'ics_stop_services');
      expect(logic.hotspotBusyStatus?.stepIndex, 2);

      // Competing ARP scans must skip while ICS service restart is running
      await logic.scanConnectedClients();
      expect(psCommands, isEmpty);

      repairCompleter.complete(
        {'Ok': true, 'ServicesRecovered': true, 'HotspotState': 'Off'},
      );
      expect(await repairFuture, isTrue);
      expect(psCommands, isEmpty);
      expect(logic.isHotspotBusy, isFalse);
      logic.dispose();
    });
  });

  group('HotspotOperationProgressBanner inline Style 1 UI', () {
    testWidgets(
        'MonitorTab displays live ICS step banner, elapsed timer, and collapses when done',
        (tester) async {
      final logic = WifiGuardLogic();
      await tester.pumpWidget(
        wrapWithApp(
          MonitorTab(
            logic: logic,
            onQuickBlock: (_) {},
            onQuickWhitelist: (_) {},
            onEditNickname: (_, __) {},
            onSnackbar: (_) {},
          ),
        ),
      );

      expect(find.byKey(const Key('hotspot-progress-banner')), findsNothing);

      final started = DateTime.now().subtract(const Duration(seconds: 7));
      logic.setHotspotBusyStatusForTesting(
        HotspotBusyStatus(
          type: HotspotOperationType.fixIcs,
          stepIndex: 4,
          totalSteps: 5,
          phaseKey: 'ics_wait_stable',
          startedAt: started,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byKey(const Key('hotspot-progress-banner')), findsOneWidget);
      expect(find.text('Đang phục hồi dịch vụ ICS / Hotspot'), findsOneWidget);
      expect(find.text('Bước 4/5'), findsOneWidget);
      expect(
        find.byKey(const Key('hotspot-progress-elapsed')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      // Clearing busy status collapses banner cleanly
      logic.setHotspotBusyStatusForTesting(null);
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byKey(const Key('hotspot-progress-banner')), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      logic.dispose();
    });

    testWidgets(
        'HotspotTab shows DHCP progress steps and disables Switch while busy',
        (tester) async {
      final logic = WifiGuardLogic();
      logic.setHotspotConfigForTesting(
        HotspotConfig(
          ssid: 'JA_Hotspot',
          passphrase: 'password123',
          band: 'Auto',
          state: 'Enabled',
          maxClients: 8,
          clientCount: 1,
        ),
      );

      await tester.pumpWidget(
        wrapWithApp(
          HotspotTab(
            logic: logic,
            onSnackbar: (_, {bool isError = false}) {},
            onNavigateToTab: (_) {},
          ),
          language: AppLanguage.en,
        ),
      );

      logic.setHotspotBusyStatusForTesting(
        HotspotBusyStatus(
          type: HotspotOperationType.fixDhcp,
          stepIndex: 2,
          totalSteps: 3,
          phaseKey: 'dhcp_repair_ics',
          startedAt: DateTime.now(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byKey(const Key('hotspot-progress-banner')), findsOneWidget);
      expect(find.text('Repairing Hotspot IP / DHCP'), findsOneWidget);
      expect(find.text('Step 2/3'), findsOneWidget);

      final toggleSwitch = tester.widget<Switch>(find.byType(Switch));
      expect(toggleSwitch.onChanged, isNull);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      logic.dispose();
    });
  });
}
