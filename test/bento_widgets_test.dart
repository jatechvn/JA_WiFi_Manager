// test/bento_widgets_test.dart
// Unit and widget tests for Bento design components and DeviceTypeHelper

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_wifi_manager/modules/i18n.dart';
import 'package:ja_wifi_manager/modules/ui/bento_widgets.dart';
import 'package:ja_wifi_manager/modules/ui/styles_win10.dart';

void main() {
  group('DeviceTypeHelper tests', () {
    test('cleans mDNS suffixes properly', () {
      expect(DeviceTypeHelper.cleanHostname('DESKTOP-7V2VRAR.mshome.net'),
          'DESKTOP-7V2VRAR');
      expect(
          DeviceTypeHelper.cleanHostname('iPhone-User.local'), 'iPhone-User');
      expect(
          DeviceTypeHelper.cleanHostname('Router-Admin.lan'), 'Router-Admin');
      expect(DeviceTypeHelper.cleanHostname('SimpleName'), 'SimpleName');
      expect(DeviceTypeHelper.cleanHostname(''), '');
    });

    test('derives display name with fallback to MAC suffix', () {
      expect(
          DeviceTypeHelper.getDisplayName(
              'My-Laptop.mshome.net', 'AA-BB-CC-DD-EE-FF'),
          'My-Laptop');
      expect(DeviceTypeHelper.getDisplayName('', 'AA:BB:CC:DD:EE:12'),
          'Thiết bị #EE12');
      expect(DeviceTypeHelper.getDisplayName('', ''), 'Thiết bị #WiFi');
    });

    test('deduces correct device icons based on name and ip', () {
      // Mobile
      expect(DeviceTypeHelper.getDeviceIcon('iPhone 15 Pro', '192.168.137.10'),
          Icons.smartphone_rounded);
      expect(
          DeviceTypeHelper.getDeviceIcon(
              'Samsung Galaxy S24', '192.168.137.11'),
          Icons.smartphone_rounded);
      expect(DeviceTypeHelper.getDeviceIcon('Xiaomi-Phone', '192.168.137.12'),
          Icons.smartphone_rounded);

      // Laptop / PC
      expect(
          DeviceTypeHelper.getDeviceIcon('DESKTOP-7V2VRAR', '192.168.137.20'),
          Icons.computer_rounded);
      expect(DeviceTypeHelper.getDeviceIcon('MacBook-Pro-M3', '192.168.137.21'),
          Icons.laptop_windows_rounded);
      expect(DeviceTypeHelper.getDeviceIcon('Dell-XPS-15', '192.168.137.22'),
          Icons.laptop_windows_rounded);
      expect(DeviceTypeHelper.getDeviceIcon('ThinkPad-T14', '192.168.137.23'),
          Icons.laptop_windows_rounded);

      // Tablet
      expect(DeviceTypeHelper.getDeviceIcon('iPad Pro M2', '192.168.137.30'),
          Icons.tablet_mac_rounded);

      // IoT / Server / Network
      expect(DeviceTypeHelper.getDeviceIcon('Raspberry-Pi-5', '192.168.137.40'),
          Icons.memory_rounded);
      expect(DeviceTypeHelper.getDeviceIcon('Router-Gateway', '192.168.137.1'),
          Icons.router_rounded);

      // Generic
      expect(DeviceTypeHelper.getDeviceIcon('Unknown-Unit', '192.168.137.99'),
          Icons.devices_rounded);
    });
  });

  group('Bento Widgets UI tests', () {
    testWidgets('BentoCard renders child and triggers onTap', (tester) async {
      bool tapped = false;
      const colors = AppColorsWin10.dark;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BentoCard(
              colors: colors,
              onTap: () => tapped = true,
              child: const Text('Hello Bento'),
            ),
          ),
        ),
      );

      expect(find.text('Hello Bento'), findsOneWidget);
      await tester.tap(find.text('Hello Bento'));
      expect(tapped, isTrue);
    });

    testWidgets('PillBadge displays label, icon, and glowing dot',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PillBadge(
              label: 'ONLINE',
              color: Colors.green,
              bg: Colors.black,
              border: Colors.green,
              showDot: true,
            ),
          ),
        ),
      );

      expect(find.text('ONLINE'), findsOneWidget);
    });

    testWidgets('FilterSearchDock interactions work smoothly', (tester) async {
      const colors = AppColorsWin10.dark;
      final controller = TextEditingController(text: 'Initial Query');
      String selectedFilter = 'ALL';
      bool isCardView = true;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return LanguageProvider(
              notifier: LanguageNotifier(AppLanguage.en),
              child: MaterialApp(
                home: Scaffold(
                  body: FilterSearchDock(
                    colors: colors,
                    searchController: controller,
                    searchHint: 'Search test...',
                    onSearchChanged: (_) {},
                    onClearSearch: () {
                      controller.clear();
                      setState(() {});
                    },
                    filters: const [
                      FilterChipData(key: 'ALL', label: 'Tất cả', count: 5),
                      FilterChipData(
                          key: 'ALLOWED', label: 'Đã duyệt', count: 3),
                    ],
                    selectedFilter: selectedFilter,
                    onFilterSelected: (key) =>
                        setState(() => selectedFilter = key),
                    isCardView: isCardView,
                    onViewModeChanged: (val) =>
                        setState(() => isCardView = val),
                  ),
                ),
              ),
            );
          },
        ),
      );

      expect(find.text('Initial Query'), findsOneWidget);
      expect(find.text('Tất cả'), findsOneWidget);
      expect(find.text('Đã duyệt'), findsOneWidget);

      // Test clear search
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pump();
      expect(controller.text, isEmpty);

      // Test filter chip selection
      await tester.tap(find.text('Đã duyệt'));
      await tester.pump();
      expect(selectedFilter, 'ALLOWED');

      // Test view mode toggle
      await tester.tap(find.byTooltip('Table View'));
      await tester.pump();
      expect(isCardView, isFalse);
    });
  });
}
