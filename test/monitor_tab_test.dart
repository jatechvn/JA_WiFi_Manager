import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_wifi_manager/modules/i18n.dart';
import 'package:ja_wifi_manager/modules/logic.dart';
import 'package:ja_wifi_manager/modules/ui/monitor_tab.dart';
import 'package:ja_wifi_manager/modules/ui/styles.dart';

void main() {
  Widget buildMonitor(
    WifiGuardLogic logic, {
    ValueChanged<String>? onNavigateToTab,
  }) {
    final languageNotifier = LanguageNotifier(AppLanguage.vi);
    return LanguageProvider(
      notifier: languageNotifier,
      child: MaterialApp(
        theme: buildThemeData(AppColors.dark),
        home: Scaffold(
          body: SizedBox(
            width: 1280,
            height: 720,
            child: MonitorTab(
              logic: logic,
              onQuickBlock: (_) {},
              onQuickWhitelist: (_) {},
              onEditNickname: (_, __) {},
              onSnackbar: (_) {},
              onNavigateToTab: onNavigateToTab,
            ),
          ),
        ),
      ),
    );
  }

  ClientDevice client({
    required String nickname,
    required bool isWhitelisted,
    required bool isBlocked,
  }) {
    return ClientDevice(
      ip: '192.168.137.${nickname.length + 10}',
      mac: 'AA-BB-CC-DD-EE-${nickname.length.toString().padLeft(2, '0')}',
      state: 'Reachable',
      nickname: nickname,
      isAllowed: isWhitelisted && !isBlocked,
      isWhitelisted: isWhitelisted,
      isBlocked: isBlocked,
    );
  }

  void useSurface(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('Guard off keeps blocked and pending clients separate',
      (tester) async {
    useSurface(tester, const Size(1280, 720));
    final logic = WifiGuardLogic();
    logic.setMonitorStateForTesting(
      isGuardActive: false,
      clients: [
        client(
            nickname: 'Allowed Device', isWhitelisted: true, isBlocked: false),
        client(
            nickname: 'Blocked Device', isWhitelisted: false, isBlocked: true),
        client(
            nickname: 'Pending Device', isWhitelisted: false, isBlocked: false),
      ],
    );

    await tester.pumpWidget(buildMonitor(logic));

    await tester.tap(find.text('Bị chặn / Lạ'));
    await tester.pump();
    expect(find.text('Blocked Device'), findsOneWidget);
    expect(find.text('Pending Device'), findsNothing);

    await tester.tap(find.text('Chờ duyệt'));
    await tester.pump();
    expect(find.text('Pending Device'), findsOneWidget);
    expect(find.text('Blocked Device'), findsNothing);
  });

  testWidgets('Guard on classifies untrusted clients as blocked',
      (tester) async {
    final logic = WifiGuardLogic();
    logic.setMonitorStateForTesting(
      isGuardActive: true,
      clients: [
        client(
            nickname: 'Allowed Device', isWhitelisted: true, isBlocked: false),
        client(
            nickname: 'Blocked Device', isWhitelisted: false, isBlocked: true),
        client(
            nickname: 'Untrusted Device',
            isWhitelisted: false,
            isBlocked: false),
      ],
    );

    await tester.pumpWidget(buildMonitor(logic));

    expect(find.text('Chờ duyệt'), findsNothing);
    await tester.tap(find.text('Bị chặn / Lạ'));
    await tester.pump();
    expect(find.text('Blocked Device'), findsOneWidget);
    expect(find.text('Untrusted Device'), findsOneWidget);
    expect(find.text('Allowed Device'), findsNothing);
  });

  testWidgets('Hotspot banner navigates to configuration', (tester) async {
    String? destination;
    await tester.pumpWidget(
      buildMonitor(
        WifiGuardLogic(),
        onNavigateToTab: (tab) => destination = tab,
      ),
    );

    await tester.tap(find.byKey(const Key('monitor-hotspot-config')));

    expect(destination, 'HOTSPOT');
  });

  testWidgets('Hotspot banner serializes toggle and ICS repair',
      (tester) async {
    final logic = _ControlledWifiGuardLogic();
    await tester.pumpWidget(buildMonitor(logic));

    await tester.tap(find.byKey(const Key('monitor-hotspot-toggle')));
    await tester.pump();
    expect(logic.toggleCalls, 1);

    await tester.tap(find.byKey(const Key('monitor-hotspot-fix-ics')),
        warnIfMissed: false);
    await tester.pump();
    expect(logic.repairCalls, 0);

    logic.toggleResult.complete(true);
    await tester.pump();

    await tester.tap(find.byKey(const Key('monitor-hotspot-fix-ics')));
    await tester.pump();
    expect(logic.repairCalls, 1);

    final hotspotSwitch =
        tester.widget<Switch>(find.byKey(const Key('monitor-hotspot-toggle')));
    expect(hotspotSwitch.onChanged, isNull);

    await tester.tap(find.byKey(const Key('monitor-hotspot-toggle')),
        warnIfMissed: false);
    await tester.pump();
    expect(logic.toggleCalls, 1);

    logic.repairResult.complete(true);
    await tester.pump();
  });
}

class _ControlledWifiGuardLogic extends WifiGuardLogic {
  final toggleResult = Completer<bool>();
  final repairResult = Completer<bool>();
  int toggleCalls = 0;
  int repairCalls = 0;

  @override
  Future<bool> setHotspotState(bool enable) {
    toggleCalls++;
    return toggleResult.future;
  }

  @override
  Future<bool> repairIcsService({bool silent = false}) {
    repairCalls++;
    return repairResult.future;
  }
}
