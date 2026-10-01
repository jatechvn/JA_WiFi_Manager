import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_wifi_manager/modules/app_config.dart';
import 'package:ja_wifi_manager/modules/logic.dart';
import 'package:ja_wifi_manager/modules/services/ota_update_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const mac = 'AA-BB-CC-DD-EE-FF';
  late WifiGuardLogic logic;
  late Directory dir;
  late List<String> commands;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('blacklist_enforcement_');
    AppConfig.setCustomBaseDirForTesting(dir.path);
    commands = [];
    logic = WifiGuardLogic(nativeCommand: (exe, args) async {
      final command = args.join(' ');
      commands.add(command);
      if (command.contains('if (\$ipEntry) { \$ipEntry.InterfaceIndex }')) {
        return ProcessResult(1, 0, '21', '');
      }
      return ProcessResult(
          1,
          0,
          jsonEncode({
            'InterfaceIndex': 21,
            'AdapterName': 'Test adapter',
            'Neighbors': [
              {
                'IPAddress': '192.168.137.50',
                'LinkLayerAddress': mac,
                'State': 6
              }
            ],
          }),
          '');
    });
  });
  tearDown(() {
    logic.dispose();
  });
  test('Guard off scan enforces blacklist and whitelisting removes rules',
      () async {
    await logic.addBlacklistDevice(mac, 'Test');
    await logic.scanConnectedClients();
    expect(commands.any((c) => c.contains('New-NetFirewallRule')), isTrue);
    expect(logic.connectedClients.single.isBlocked, isTrue);
    commands.clear();
    await logic.addWhitelistDevice(mac, 'Test');
    expect(commands.any((c) => c.contains('Remove-NetFirewallRule')), isTrue);
    expect(commands.any((c) => c.contains('Remove-NetNeighbor')), isTrue);
    expect(logic.connectedClients.single.isBlocked, isFalse);
  });
  test('Stopping Guard preserves blacklist enforcement', () async {
    await logic.addBlacklistDevice(mac, 'Test');
    await logic.scanConnectedClients();
    logic.setMonitorStateForTesting(
        clients: logic.connectedClients, isGuardActive: true);
    commands.clear();
    await logic.stopGuard();
    expect(
        commands.any((c) => c.contains('DisplayName "WiFiGuard_*"')), isFalse);
    expect(logic.connectedClients.single.isBlocked, isTrue);
  });
  test('Rollback checks robocopy failure before config copy or restart', () {
    final script = OtaUpdateService.generateApplyUpdateScript(
        oldPid: 42,
        sourceDir: r'C:\stage',
        targetDir: r'C:\app',
        exeName: 'app.exe');
    final rollback = script.substring(script.indexOf(':rollback\n'));
    expect(rollback.indexOf('if errorlevel 8 exit /b 14'),
        lessThan(rollback.indexOf('for %%F')));
    expect(rollback.indexOf('if errorlevel 8 exit /b 14'),
        lessThan(rollback.indexOf('start ""')));
  });
}
