import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_wifi_manager/modules/i18n.dart';
import 'package:ja_wifi_manager/modules/logic.dart';
import 'package:ja_wifi_manager/modules/ui/whitelist_tab.dart';
import 'package:ja_wifi_manager/modules/ui/console_tab.dart';
import 'package:ja_wifi_manager/modules/ui/hotspot_tab.dart';
import 'package:ja_wifi_manager/modules/ui/settings_tab.dart';
import 'package:ja_wifi_manager/modules/ui/styles.dart';

void main() {
  Widget wrapWithTheme(
    Widget child, {
    AppLanguage language = AppLanguage.vi,
  }) {
    final languageNotifier = LanguageNotifier(language);
    return LanguageProvider(
      notifier: languageNotifier,
      child: MaterialApp(
        theme: buildThemeData(AppColors.dark),
        home: Scaffold(body: child),
      ),
    );
  }

  void useSurface(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  group('Remade Tabs Bento UI Tests', () {
    testWidgets('WhitelistTab renders Bento stats and device list correctly',
        (tester) async {
      final logic = WifiGuardLogic();
      logic.whitelist.addAll([
        WhitelistEntry(mac: '11:22:33:44:55:66', nickname: 'Laptop ThinkPad'),
        WhitelistEntry(mac: 'AA:BB:CC:DD:EE:FF', nickname: 'iPhone 15 Pro'),
      ]);

      await tester.pumpWidget(
        wrapWithTheme(
          WhitelistTab(
            logic: logic,
            onAddDevice: () {},
            onEditNickname: (_, __) {},
            onDeleteDevice: (_) {},
          ),
        ),
      );

      // Verify stats cards
      expect(find.text('Thiết bị tin cậy'), findsOneWidget);
      expect(find.text('Đang kết nối'), findsOneWidget);
      expect(find.text('Ngoại tuyến'), findsOneWidget);
      expect(find.text('Laptop ThinkPad'), findsOneWidget);
      expect(find.text('iPhone 15 Pro'), findsOneWidget);
      expect(find.text('11:22:33:44:55:66'), findsOneWidget);
    });

    testWidgets('WhitelistTab follows the selected language', (tester) async {
      useSurface(tester, const Size(1280, 800));
      final logic = WifiGuardLogic();
      logic.whitelist.add(
        WhitelistEntry(mac: '11:22:33:44:55:66', nickname: ''),
      );

      await tester.pumpWidget(
        wrapWithTheme(
          WhitelistTab(
            logic: logic,
            onAddDevice: () {},
            onEditNickname: (_, __) {},
            onDeleteDevice: (_) {},
          ),
          language: AppLanguage.en,
        ),
      );
      expect(find.text('Trusted Whitelist'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Unnamed device'), findsOneWidget);
      expect(find.text('OFFLINE'), findsOneWidget);

      await tester.pumpWidget(
        wrapWithTheme(
          WhitelistTab(
            logic: logic,
            onAddDevice: () {},
            onEditNickname: (_, __) {},
            onDeleteDevice: (_) {},
          ),
          language: AppLanguage.zh,
        ),
      );
      expect(find.text('信任白名单'), findsOneWidget);
      expect(find.text('全部'), findsOneWidget);
      expect(find.text('未命名设备'), findsOneWidget);
      expect(find.text('离线'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ConsoleTab renders terminal chrome and filters log lines',
        (tester) async {
      final logic = WifiGuardLogic();
      logic.logLines.addAll([
        '[BLOCK] Device 11-22-33 blocked from network',
        '[ALLOW] Device 44-55-66 verified in whitelist',
        '[WARN] ICS service latency detected',
      ]);

      String currentFilter = 'ALL';
      final scrollController = ScrollController();

      await tester.pumpWidget(
        wrapWithTheme(
          StatefulBuilder(
            builder: (context, setState) {
              return ConsoleTab(
                logic: logic,
                logScrollController: scrollController,
                logLevelFilter: currentFilter,
                onLogLevelFilterChanged: (f) =>
                    setState(() => currentFilter = f),
                autoScrollLogs: true,
                onAutoScrollChanged: (_) {},
                onSnackbar: (_) {},
              );
            },
          ),
        ),
      );

      // Verify terminal chrome title
      expect(
        find.text('JA WiFi Guard Console • live_stream.log'),
        findsOneWidget,
      );
      expect(find.text('ĐANG NHẬN'), findsOneWidget);
      expect(find.text('Tự cuộn'), findsOneWidget);

      // Verify log contents
      expect(
        find.textContaining('Device 11-22-33 blocked'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Device 44-55-66 verified'),
        findsOneWidget,
      );

      // Switch to BLOCKS filter
      await tester.tap(find.text('Chặn'));
      await tester.pump();
      expect(
        find.textContaining('Device 11-22-33 blocked'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Device 44-55-66 verified'),
        findsNothing,
      );
    });

    testWidgets('HotspotTab renders Hero card and Wi-Fi configuration form',
        (tester) async {
      final logic = WifiGuardLogic();
      logic.setHotspotConfigForTesting(HotspotConfig(
        state: 'Enabled',
        ssid: 'JA_Office_WiFi',
        passphrase: 'securepassword123',
        band: 'TwoPointFourGigahertz',
        clientCount: 2,
        maxClients: 8,
      ));

      await tester.pumpWidget(
        wrapWithTheme(
          HotspotTab(
            logic: logic,
            onSnackbar: (_, {isError = false}) {},
            onNavigateToTab: (_) {},
          ),
        ),
      );

      // Verify Hero card items
      expect(find.text('JA_Office_WiFi'), findsWidgets);
      expect(find.text('ONLINE'), findsOneWidget);
      expect(find.text('2.4 GHz'), findsWidgets);
      expect(find.text('Sửa lỗi ICS (Kill PID)'), findsOneWidget);
      expect(find.text('Sửa IP/DHCP'), findsOneWidget);
      expect(find.text('Cấu hình mạng Wi-Fi'), findsOneWidget);
    });

    testWidgets(
        'SettingsTab renders Bento cards and segmented interval control',
        (tester) async {
      final logic = WifiGuardLogic();

      await tester.pumpWidget(
        wrapWithTheme(
          SettingsTab(
            logic: logic,
            startupWithWindows: false,
            onStartupWithWindowsChanged: (_) {},
            startMinimized: true,
            onStartMinimizedChanged: (_) {},
            closeToTray: true,
            onCloseToTrayChanged: (_) {},
            autoStartGuard: true,
            onAutoStartGuardChanged: (_) {},
            autoStartHotspot: false,
            onAutoStartHotspotChanged: (_) {},
            onImportWhitelist: () {},
            onExportWhitelist: () {},
            onSnackbar: (_) {},
          ),
        ),
      );

      // Verify system preferences items
      expect(find.text('Tần suất quét bảo vệ'), findsOneWidget);
      expect(find.text('5s'), findsOneWidget);
      expect(find.text('10s'), findsOneWidget);
      expect(find.text('30s'), findsOneWidget);
      expect(find.text('Sao lưu Whitelist'), findsOneWidget);
      expect(find.text('Nhập file'), findsOneWidget);
      expect(find.text('Xuất file'), findsOneWidget);
      expect(find.text('Tài liệu hướng dẫn & Trợ giúp'), findsOneWidget);
    });

    testWidgets('ConsoleTab uses English strings when the language is English',
        (tester) async {
      useSurface(tester, const Size(1280, 800));
      final logic = WifiGuardLogic();
      await tester.pumpWidget(
        wrapWithTheme(
          ConsoleTab(
            logic: logic,
            logScrollController: ScrollController(),
            logLevelFilter: 'ALL',
            onLogLevelFilterChanged: (_) {},
            autoScrollLogs: true,
            onAutoScrollChanged: (_) {},
            onSnackbar: (_) {},
          ),
          language: AppLanguage.en,
        ),
      );

      expect(find.text('STREAM ACTIVE'), findsOneWidget);
      expect(find.text('Blocks'), findsOneWidget);
      expect(find.text('Auto Scroll'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('remade tabs do not overflow at 720px', (tester) async {
      useSurface(tester, const Size(720, 900));
      final logic = WifiGuardLogic();
      logic.whitelist.add(
        WhitelistEntry(mac: '11:22:33:44:55:66', nickname: 'Laptop ThinkPad'),
      );
      logic.logLines.add('[BLOCK] narrow layout check');
      logic.setHotspotConfigForTesting(HotspotConfig(
        state: 'Enabled',
        ssid: 'JA_Office_WiFi_${'VeryLongNetworkName' * 4}',
        passphrase: 'securepassword123',
        band: 'TwoPointFourGigahertz',
        clientCount: 2,
        maxClients: 8,
      ));

      Future<void> pumpTab(Widget child) async {
        await tester.pumpWidget(wrapWithTheme(child));
        await tester.pump();
        expect(tester.takeException(), isNull);
      }

      await pumpTab(
        WhitelistTab(
          logic: logic,
          onAddDevice: () {},
          onEditNickname: (_, __) {},
          onDeleteDevice: (_) {},
        ),
      );
      expect(find.text('Thiết bị tin cậy'), findsOneWidget);

      await pumpTab(
        ConsoleTab(
          logic: logic,
          logScrollController: ScrollController(),
          logLevelFilter: 'ALL',
          onLogLevelFilterChanged: (_) {},
          autoScrollLogs: false,
          onAutoScrollChanged: (_) {},
          onSnackbar: (_) {},
        ),
      );
      expect(find.text('ĐANG NHẬN'), findsOneWidget);

      await pumpTab(
        HotspotTab(
          logic: logic,
          onSnackbar: (_, {isError = false}) {},
          onNavigateToTab: (_) {},
        ),
      );
      expect(find.text('ONLINE'), findsOneWidget);
      expect(find.text('Lưu cấu hình'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);

      await pumpTab(
        SettingsTab(
          logic: logic,
          startupWithWindows: false,
          onStartupWithWindowsChanged: (_) {},
          startMinimized: false,
          onStartMinimizedChanged: (_) {},
          closeToTray: false,
          onCloseToTrayChanged: (_) {},
          autoStartGuard: false,
          onAutoStartGuardChanged: (_) {},
          autoStartHotspot: false,
          onAutoStartHotspotChanged: (_) {},
          onImportWhitelist: () {},
          onExportWhitelist: () {},
          onSnackbar: (_) {},
        ),
      );
      expect(find.text('5s'), findsOneWidget);
      expect(find.text('Mở thư mục cấu hình'), findsOneWidget);
      expect(find.text('Lưu cấu hình OTA'), findsOneWidget);
    });
  });
}
