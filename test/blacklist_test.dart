// test/blacklist_test.dart
// Unit tests for Blacklist management, mutual exclusion, and universal device naming

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_wifi_manager/modules/logic.dart';
import 'package:ja_wifi_manager/modules/app_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late WifiGuardLogic logic;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('ja_wifi_blacklist_test_');
    AppConfig.setCustomBaseDirForTesting(tempDir.path);
    logic = WifiGuardLogic();
    await logic.initialize();
  });

  tearDown(() {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('BlacklistEntry Model Tests', () {
    test('toJson and fromJson work correctly', () {
      final now = DateTime.now();
      final entry = BlacklistEntry(
        mac: 'AA-BB-CC-DD-EE-FF',
        nickname: 'Intruder Phone',
        addedAt: now,
        reason: 'Suspicious traffic',
      );

      final json = entry.toJson();
      expect(json['mac'], equals('AA-BB-CC-DD-EE-FF'));
      expect(json['nickname'], equals('Intruder Phone'));
      expect(json['reason'], equals('Suspicious traffic'));

      final parsed = BlacklistEntry.fromJson(json);
      expect(parsed.mac, equals('AA-BB-CC-DD-EE-FF'));
      expect(parsed.nickname, equals('Intruder Phone'));
      expect(parsed.reason, equals('Suspicious traffic'));
      expect(parsed.addedAt.year, equals(now.year));
    });
  });

  group('Blacklist CRUD and Mutual Exclusion Tests', () {
    test('Add device to blacklist works and persists', () async {
      final success = await logic.addBlacklistDevice(
        '11-22-33-44-55-66',
        'Bad Device',
        reason: 'Port scan detected',
      );

      expect(success, isTrue);
      expect(logic.isBlacklisted('11-22-33-44-55-66'), isTrue);
      expect(logic.blacklist.length, equals(1));
      expect(logic.blacklist.first.nickname, equals('Bad Device'));
      expect(logic.blacklist.first.reason, equals('Port scan detected'));

      // Check file persistence
      final file = File(AppConfig.getBlacklistPath());
      expect(file.existsSync(), isTrue);
      expect(file.readAsStringSync(), contains('11-22-33-44-55-66'));
    });

    test(
        'Mutual exclusion: Adding whitelisted device to blacklist removes it from whitelist',
        () async {
      await logic.addWhitelistDevice('AA-BB-CC-11-22-33', 'My Laptop');
      expect(logic.isWhitelisted('AA-BB-CC-11-22-33'), isTrue);
      expect(logic.isBlacklisted('AA-BB-CC-11-22-33'), isFalse);

      // Now add to blacklist
      final success = await logic.addBlacklistDevice(
        'AA-BB-CC-11-22-33',
        'Stolen Laptop',
        reason: 'Marked as compromised',
      );
      expect(success, isTrue);

      // Should now be in blacklist and NOT in whitelist
      expect(logic.isBlacklisted('AA-BB-CC-11-22-33'), isTrue);
      expect(logic.isWhitelisted('AA-BB-CC-11-22-33'), isFalse);
    });

    test(
        'Mutual exclusion: Adding blacklisted device to whitelist removes it from blacklist',
        () async {
      await logic.addBlacklistDevice('AA-BB-CC-44-55-66', 'Blocked Guy');
      expect(logic.isBlacklisted('AA-BB-CC-44-55-66'), isTrue);
      expect(logic.isWhitelisted('AA-BB-CC-44-55-66'), isFalse);

      // Now add to whitelist
      final success =
          await logic.addWhitelistDevice('AA-BB-CC-44-55-66', 'Approved Guy');
      expect(success, isTrue);

      // Should now be in whitelist and NOT in blacklist
      expect(logic.isWhitelisted('AA-BB-CC-44-55-66'), isTrue);
      expect(logic.isBlacklisted('AA-BB-CC-44-55-66'), isFalse);
    });

    test('moveToWhitelist and moveToBlacklist transfer entries smoothly',
        () async {
      await logic.addBlacklistDevice('AA-11-22-33-44-55', 'Test Device');
      expect(logic.isBlacklisted('AA-11-22-33-44-55'), isTrue);

      // Move to whitelist
      final movedToWl = await logic.moveToWhitelist('AA-11-22-33-44-55');
      expect(movedToWl, isTrue);
      expect(logic.isWhitelisted('AA-11-22-33-44-55'), isTrue);
      expect(logic.isBlacklisted('AA-11-22-33-44-55'), isFalse);

      // Move back to blacklist
      final movedToBl =
          await logic.moveToBlacklist('AA-11-22-33-44-55', reason: 'Retested');
      expect(movedToBl, isTrue);
      expect(logic.isBlacklisted('AA-11-22-33-44-55'), isTrue);
      expect(logic.isWhitelisted('AA-11-22-33-44-55'), isFalse);
      expect(logic.blacklist.first.reason, equals('Retested'));
    });

    test(
        'Filtered blacklist supports search query across MAC, name, and reason',
        () async {
      await logic.addBlacklistDevice('11-11-11-11-11-11', 'Attacker Alpha',
          reason: 'DDOS attempt');
      await logic.addBlacklistDevice('22-22-22-22-22-22', 'Attacker Beta',
          reason: 'ARP spoof');

      logic.setSearchQuery('Alpha');
      expect(logic.filteredBlacklist.length, equals(1));
      expect(logic.filteredBlacklist.first.mac, equals('11-11-11-11-11-11'));

      logic.setSearchQuery('spoof');
      expect(logic.filteredBlacklist.length, equals(1));
      expect(logic.filteredBlacklist.first.mac, equals('22-22-22-22-22-22'));

      logic.setSearchQuery('11-11');
      expect(logic.filteredBlacklist.length, equals(1));

      logic.setSearchQuery('');
      expect(logic.filteredBlacklist.length, equals(2));
    });
  });

  group('Universal Persistent Device Renaming Tests', () {
    test(
        'editDeviceNickname persists to device_names.json and reflects across all lists',
        () async {
      const mac = 'AA-BB-CC-DD-11-22';

      // Simulate a connected client that is not in whitelist or blacklist yet
      logic.setMonitorStateForTesting(
        clients: [
          ClientDevice(
            ip: '192.168.137.50',
            mac: mac,
            state: 'Reachable',
            nickname: 'Unknown Phone',
            isAllowed: false,
            isWhitelisted: false,
            isBlocked: false,
          ),
        ],
        isGuardActive: false,
      );

      expect(logic.connectedClients.first.nickname, equals('Unknown Phone'));

      // User renames the device from anywhere (e.g. MonitorTab)
      await logic.editDeviceNickname(mac, "Alice's iPhone 15");

      // 1. Should update connectedClients in memory immediately
      expect(
          logic.connectedClients.first.nickname, equals("Alice's iPhone 15"));

      // 2. Should persist to device_names.json
      final namesFile = File(AppConfig.getDeviceNamesPath());
      expect(namesFile.existsSync(), isTrue);
      expect(namesFile.readAsStringSync(), contains("Alice's iPhone 15"));

      // 3. getEffectiveNickname should return the custom nickname
      expect(logic.getEffectiveNickname(mac), equals("Alice's iPhone 15"));

      // 4. If subsequently added to whitelist, it retains the custom nickname
      await logic.addWhitelistDevice(mac, '');
      expect(
          logic.whitelist
              .any((e) => e.mac == mac && e.nickname == "Alice's iPhone 15"),
          isTrue);

      // 5. Renaming again syncs to whitelist too
      await logic.editDeviceNickname(mac, "Alice's Work Phone");
      expect(logic.whitelist.firstWhere((e) => e.mac == mac).nickname,
          equals("Alice's Work Phone"));
      expect(
          logic.connectedClients.first.nickname, equals("Alice's Work Phone"));
    });

    test('Reloading device_names.json preserves nicknames after restart',
        () async {
      const mac = '99-88-77-66-55-44';
      await logic.editDeviceNickname(mac, 'Boss Laptop');

      // Create a fresh logic instance and initialize
      final freshLogic = WifiGuardLogic();
      await freshLogic.initialize();

      expect(freshLogic.customNicknames[mac], equals('Boss Laptop'));
      expect(freshLogic.getEffectiveNickname(mac), equals('Boss Laptop'));
    });
  });
}
