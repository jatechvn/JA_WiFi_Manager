import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_wifi_manager/modules/app_config.dart';
import 'package:ja_wifi_manager/modules/logic.dart';
import 'package:ja_wifi_manager/modules/utils/atomic_file_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('stability_improvements_');
    AppConfig.setCustomBaseDirForTesting(tempDir.path);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  group('AtomicFileStore resilience & auto-recovery', () {
    test('Creates .bak on overwrite and auto-recovers from corrupted JSON',
        () async {
      final path = '${tempDir.path}/whitelist.json';
      const firstPayload = '[{"mac":"AA-BB-CC-DD-EE-01","nickname":"First"}]';
      const secondPayload = '[{"mac":"AA-BB-CC-DD-EE-02","nickname":"Second"}]';

      await AtomicFileStore.writeStringAtomic(
        path,
        firstPayload,
        validator: AtomicFileStore.isValidJson,
      );
      await AtomicFileStore.writeStringAtomic(
        path,
        secondPayload,
        validator: AtomicFileStore.isValidJson,
      );

      final bakFile = File('$path.bak');
      expect(bakFile.existsSync(), isTrue);
      expect(bakFile.readAsStringSync(), equals(firstPayload));

      // Simulate sudden power loss corrupting primary file with partial JSON
      File(path).writeAsStringSync('[{"mac":"BROKEN');

      final recovered = await AtomicFileStore.readStringResilient(
        path,
        validator: AtomicFileStore.isValidJson,
      );
      expect(recovered, equals(firstPayload));
      // Primary file should also be self-healed
      expect(File(path).readAsStringSync(), equals(firstPayload));
    });

    test('Auto-recovers from 0-byte truncated INI file via AppConfig',
        () async {
      await AppConfig.set('theme_mode', 'dark');
      await AppConfig.set('language', 'vi');

      final configPath = AppConfig.getConfigPath();
      expect(File('$configPath.bak').existsSync(), isTrue);

      // Corrupt primary config.ini to 0 bytes
      File(configPath).writeAsStringSync('');

      // Reload AppConfig from disk
      await AppConfig.reloadForTesting();
      expect(AppConfig.get('theme_mode'), equals('dark'));
    });
  });

  group('Persistent blocked_session.json state across log clear & restart', () {
    test(
        'Blocked MAC mapping survives clearLogs() and rebuildSessionStateFromLog()',
        () async {
      const mac = 'AA-BB-CC-DD-EE-99';
      const ip = '192.168.137.99';

      final logic1 = WifiGuardLogic(nativeCommand: (exe, args) async {
        return ProcessResult(
          1,
          0,
          jsonEncode({
            'InterfaceIndex': 21,
            'AdapterName': 'Local Area Connection* 10',
            'Neighbors': [
              {
                'IPAddress': ip,
                'LinkLayerAddress': mac,
                'State': 6,
              }
            ],
          }),
          '',
        );
      });

      await logic1.addBlacklistDevice(mac, 'Intruder');
      await logic1.scanConnectedClients();
      expect(logic1.connectedClients.single.isBlocked, isTrue);
      expect(File(AppConfig.getBlockedSessionPath()).existsSync(), isTrue);

      // User clears logs on Console tab
      await logic1.clearLogs();
      expect(logic1.logLines, isEmpty);
      logic1.dispose();

      // Simulate app restart when ARP neighbor now reports poisoned MAC 00-00-00-00-00-01
      final logic2 = WifiGuardLogic(nativeCommand: (exe, args) async {
        return ProcessResult(
          1,
          0,
          jsonEncode({
            'InterfaceIndex': 21,
            'AdapterName': 'Local Area Connection* 10',
            'Neighbors': [
              {
                'IPAddress': ip,
                'LinkLayerAddress': '00-00-00-00-00-01',
                'State': 2,
              }
            ],
          }),
          '',
        );
      });

      await logic2.loadBlacklist();
      await logic2.rebuildSessionStateFromLog();
      await logic2.scanConnectedClients();

      // Real MAC and Blocked status must still be resolved from blocked_session.json
      expect(logic2.connectedClients, hasLength(1));
      expect(logic2.connectedClients.single.mac, equals(mac));
      expect(logic2.connectedClients.single.isBlocked, isTrue);
      logic2.dispose();
    });
  });

  group('Re-entrancy guard & batched idempotent enforcement', () {
    test(
        'Concurrent scanConnectedClients() calls coalesce into a single native execution',
        () async {
      int scanCount = 0;
      final completer = Completer<void>();

      final logic = WifiGuardLogic(nativeCommand: (exe, args) async {
        final cmd = args.join(' ');
        if (cmd.contains('Get-NetNeighbor')) {
          scanCount++;
          await completer.future;
          return ProcessResult(
            1,
            0,
            jsonEncode({
              'InterfaceIndex': 21,
              'AdapterName': 'Local Area Connection* 10',
              'Neighbors': [],
            }),
            '',
          );
        }
        return ProcessResult(1, 0, '', '');
      });

      final f1 = logic.scanConnectedClients();
      final f2 = logic.scanConnectedClients();
      final f3 = logic.scanConnectedClients();

      completer.complete();
      await Future.wait([f1, f2, f3]);

      expect(scanCount, equals(1));
      logic.dispose();
    });

    test(
        'Firewall block rule is idempotent and includes MAC metadata description',
        () async {
      const mac = '11-22-33-44-55-66';
      final commands = <String>[];

      final logic = WifiGuardLogic(nativeCommand: (exe, args) async {
        final cmd = args.join(' ');
        commands.add(cmd);
        return ProcessResult(
          1,
          0,
          jsonEncode({
            'InterfaceIndex': 21,
            'AdapterName': 'Local Area Connection* 10',
            'Neighbors': [
              {
                'IPAddress': '192.168.137.77',
                'LinkLayerAddress': mac,
                'State': 6,
              }
            ],
          }),
          '',
        );
      });

      await logic.addBlacklistDevice(mac, 'BlockedPhone');
      commands.clear();
      await logic.scanConnectedClients();

      final blockCmds =
          commands.where((c) => c.contains('New-NetFirewallRule')).toList();
      expect(blockCmds, hasLength(1));
      // Combined ARP + idempotent Firewall rule in a single PowerShell invocation
      expect(blockCmds.single, contains('Remove-NetFirewallRule'));
      expect(blockCmds.single, contains('Description "MAC=$mac"'));
      expect(blockCmds.single, contains('New-NetNeighbor'));

      logic.dispose();
    });
  });

  group('Hotspot Watchdog auto-heal & user intent tracking', () {
    test(
        'Auto-heals when Windows disables Hotspot, but respects user manual turn-off',
        () async {
      String mockHotspotState = 'Disabled';
      int startTetheringCalls = 0;

      final logic = WifiGuardLogic(nativeCommand: (exe, args) async {
        final cmd = args.join(' ');
        if (cmd.contains('StartTetheringAsync')) {
          startTetheringCalls++;
          mockHotspotState = 'Enabled';
          return ProcessResult(1, 0, 'Success', '');
        }
        if (cmd.contains('StopTetheringAsync')) {
          mockHotspotState = 'Disabled';
          return ProcessResult(1, 0, 'Success', '');
        }
        if (cmd.contains('CreateFromConnectionProfile')) {
          return ProcessResult(
            1,
            0,
            jsonEncode({
              'Ssid': 'JA_Hotspot',
              'Passphrase': 'password123',
              'Band': 'Auto',
              'State': mockHotspotState,
              'MaxClients': 8,
              'ClientCount': 0,
            }),
            '',
          );
        }
        return ProcessResult(1, 0, '', '');
      });

      // 1. Hotspot unexpectedly turns Disabled while autoStartHotspot is enabled -> Watchdog heals it
      final healed = await logic.checkAndHealHotspotIfNeeded(
        autoStartHotspotEnabled: true,
        cooldown: Duration.zero,
      );
      expect(healed, isTrue);
      expect(startTetheringCalls, equals(1));
      expect(logic.hotspotConfig?.state, equals('Enabled'));

      // 2. User manually stops Hotspot from UI -> Watchdog must NOT re-enable it
      await logic.setHotspotState(false, isUserInitiated: true);
      expect(logic.userManuallyStoppedHotspot, isTrue);

      final healedAfterManualStop = await logic.checkAndHealHotspotIfNeeded(
        autoStartHotspotEnabled: true,
        cooldown: Duration.zero,
      );
      expect(healedAfterManualStop, isFalse);
      expect(startTetheringCalls, equals(1));

      logic.dispose();
    });
  });
}
