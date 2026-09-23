// test/ota_update_service_test.dart
// Unit tests for LAN OTA Update Service in JA WiFi Hotspot Guard

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_wifi_manager/modules/services/ota_update_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late File configFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ja_wifi_ota_test_');
    configFile = File('${tempDir.path}/update_config.json');

    OtaUpdateService().setCustomConfigFileForTesting(configFile);
    OtaUpdateService().setCustomServerDirForTesting(null);
  });

  tearDown(() async {
    OtaUpdateService().setCustomConfigFileForTesting(null);
    OtaUpdateService().setCustomServerDirForTesting(null);

    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  group('SemanticVersion Unit Tests', () {
    test('Correctly parses SemVer formats with and without prefix', () {
      final v1 = SemanticVersion.tryParse('1.0.0');
      expect(v1, isNotNull);
      expect(v1!.major, equals(1));
      expect(v1.minor, equals(0));
      expect(v1.patch, equals(0));
      expect(v1.build, isNull);

      final v2 = SemanticVersion.tryParse('v2.4.1+15');
      expect(v2, isNotNull);
      expect(v2!.major, equals(2));
      expect(v2.minor, equals(4));
      expect(v2.patch, equals(1));
      expect(v2.build, equals(15));

      final v3 = SemanticVersion.tryParse('1.1');
      expect(v3, isNotNull);
      expect(v3!.major, equals(1));
      expect(v3.minor, equals(1));
      expect(v3.patch, equals(0));

      final vInvalid = SemanticVersion.tryParse('invalid_version_string');
      expect(vInvalid, isNull);

      final vNull = SemanticVersion.tryParse(null);
      expect(vNull, isNull);

      final vQuad = SemanticVersion.tryParse('1.2.3.4');
      expect(vQuad, isNull);
    });

    test('SemanticVersion comparison operators work correctly', () {
      final v100 = SemanticVersion.tryParse('1.0.0')!;
      final v101 = SemanticVersion.tryParse('1.0.1')!;
      final v110 = SemanticVersion.tryParse('1.1.0')!;
      final v200 = SemanticVersion.tryParse('2.0.0')!;
      final v100b1 = SemanticVersion.tryParse('1.0.0+1')!;
      final v100b2 = SemanticVersion.tryParse('1.0.0+2')!;

      expect(v100 < v101, isTrue);
      expect(v101 < v110, isTrue);
      expect(v110 < v200, isTrue);
      expect(v200 > v110, isTrue);
      expect(v100b1 < v100b2, isTrue);
      expect(v100 == SemanticVersion.tryParse('1.0.0')!, isTrue);
      expect(v110 >= v100, isTrue);
      expect(v100 <= v110, isTrue);
      expect(v100 > v110, isFalse);
    });

    test('Prerelease versions order before release versions', () {
      final rc2 = SemanticVersion.tryParse('1.2.0-rc.2')!;
      final rc10 = SemanticVersion.tryParse('1.2.0-rc.10')!;
      final rel = SemanticVersion.tryParse('1.2.0')!;

      expect(rc2 < rc10, isTrue);
      expect(rc10 < rel, isTrue);
    });

    test('Display version formats correctly', () {
      final v = SemanticVersion.tryParse('v1.1.7');
      expect(v?.displayVersion, equals('v1.1.7'));
    });
  });

  group('OtaUpdateService Logic & Validation Tests', () {
    test('isValidPackageName validates correct format and blocks traversal',
        () {
      expect(
        OtaUpdateService.isValidPackageName(
            'JA_WiFi_Manager_v1.1.8_Windows_x64.zip'),
        isTrue,
      );
      expect(
        OtaUpdateService.isValidPackageName('JA_WiFi_Manager_1.2.0.zip'),
        isTrue,
      );
      expect(
        OtaUpdateService.isValidPackageName(
            '../JA_WiFi_Manager_v1.1.8_Windows_x64.zip'),
        isFalse,
      );
      expect(
        OtaUpdateService.isValidPackageName('OtherApp_v1.1.8_Windows_x64.zip'),
        isFalse,
      );
      expect(
        OtaUpdateService.isValidPackageName('JA_WiFi_Manager_v1.1.8..zip'),
        isFalse,
      );
    });

    test('extractSmbShareRoot extracts correctly', () {
      expect(
        OtaUpdateService.extractSmbShareRoot(
            r'\\10.81.141.226\temp\FBT\JA_PROJECT'),
        equals(r'\\10.81.141.226\temp'),
      );
      expect(
        OtaUpdateService.extractSmbShareRoot(r'\\192.168.1.100\SharedFolder'),
        equals(r'\\192.168.1.100\SharedFolder'),
      );
      expect(
        OtaUpdateService.extractSmbShareRoot('//10.81.141.226/temp/subfolder'),
        equals(r'\\10.81.141.226\temp'),
      );
      expect(
        OtaUpdateService.extractSmbShareRoot(r'C:\LocalFolder'),
        isNull,
      );
    });

    test('shouldCheckForUpdates interval calculation', () {
      final service = OtaUpdateService();
      final now = DateTime(2026, 9, 21, 12, 0);

      // Off always false
      expect(
        service.shouldCheckForUpdates(
          interval: 'off',
          lastCheckTime: null,
          now: now,
        ),
        isFalse,
      );

      // Null last check always true if not off
      expect(
        service.shouldCheckForUpdates(
          interval: 'daily',
          lastCheckTime: null,
          now: now,
        ),
        isTrue,
      );

      // Daily: 23 hours elapsed -> false
      expect(
        service.shouldCheckForUpdates(
          interval: 'daily',
          lastCheckTime: now.subtract(const Duration(hours: 23)),
          now: now,
        ),
        isFalse,
      );

      // Daily: 25 hours elapsed -> true
      expect(
        service.shouldCheckForUpdates(
          interval: 'daily',
          lastCheckTime: now.subtract(const Duration(hours: 25)),
          now: now,
        ),
        isTrue,
      );

      // Weekly: 6 days elapsed -> false
      expect(
        service.shouldCheckForUpdates(
          interval: 'weekly',
          lastCheckTime: now.subtract(const Duration(days: 6)),
          now: now,
        ),
        isFalse,
      );

      // Weekly: 8 days elapsed -> true
      expect(
        service.shouldCheckForUpdates(
          interval: 'weekly',
          lastCheckTime: now.subtract(const Duration(days: 8)),
          now: now,
        ),
        isTrue,
      );
    });

    test('OtaUpdateConfig saves non-secret fields only', () async {
      final service = OtaUpdateService();

      const config = OtaUpdateConfig(
        serverPath: r'\\my-server\share\updates',
        checkInterval: 'weekly',
        autoDownload: true,
      );

      expect(await service.saveExternalConfigFile(config), isTrue);
      expect(configFile.existsSync(), isTrue);
      expect(await configFile.readAsString(), isNot(contains('password')));

      final loaded = await service.loadExternalConfigFile();
      expect(loaded.serverPath, equals(r'\\my-server\share\updates'));
      expect(loaded.checkInterval, equals('weekly'));
      expect(loaded.autoDownload, isTrue);
    });

    test('saveExternalConfigFile reports an unwritable target', () async {
      final service = OtaUpdateService();
      service.setCustomConfigFileForTesting(
        File('${tempDir.path}/missing/update_config.json'),
      );

      expect(
        await service.saveExternalConfigFile(OtaUpdateConfig.defaults()),
        isFalse,
      );
    });

    test(
        'generateApplyUpdateScript generates correct script and protects config',
        () {
      final script = OtaUpdateService.generateApplyUpdateScript(
        oldPid: 1234,
        sourceDir: r'C:\temp\source',
        targetDir: r'C:\App\JA_WiFi_Manager',
        exeName: 'ja_wifi_manager.exe',
      );

      expect(script.contains('set "OLD_PID=1234"'), isTrue);
      expect(script.contains(r'set "SRC_DIR=C:\temp\source"'), isTrue);
      expect(script.contains(r'set "DST_DIR=C:\App\JA_WiFi_Manager"'), isTrue);
      expect(script.contains('set "EXE_NAME=ja_wifi_manager.exe"'), isTrue);
      expect(
        script.contains(r'/XF config.ini update_config.json whitelist.json'),
        isTrue,
      );
      expect(script.contains(':rollback'), isTrue);
    });

    test('generateApplyUpdateScript throws on invalid arguments', () {
      expect(
        () => OtaUpdateService.generateApplyUpdateScript(
          oldPid: -1,
          sourceDir: r'C:\temp',
          targetDir: r'C:\app',
          exeName: 'app.exe',
        ),
        throwsArgumentError,
      );

      expect(
        () => OtaUpdateService.generateApplyUpdateScript(
          oldPid: 100,
          sourceDir: 'C:\\temp"malicious',
          targetDir: r'C:\app',
          exeName: 'app.exe',
        ),
        throwsArgumentError,
      );
    });

    test('checkForUpdates detects updates from mock server directory',
        () async {
      final mockServer = Directory('${tempDir.path}/mock_server')..createSync();
      OtaUpdateService().setCustomServerDirForTesting(mockServer);

      // Create version.json on mock server
      final versionJson = File('${mockServer.path}/version.json');
      final zipPkg =
          File('${mockServer.path}/JA_WiFi_Manager_v1.2.0_Windows_x64.zip');
      zipPkg.writeAsStringSync('fixture_zip_content');
      final sha256 = await OtaUpdateService().calculateSha256ForTesting(zipPkg);

      versionJson.writeAsStringSync(jsonEncode({
        'version': '1.2.0',
        'fileName': 'JA_WiFi_Manager_v1.2.0_Windows_x64.zip',
        'sha256': sha256,
        'releaseNotes': 'Bản cập nhật lớn giao diện và tính năng OTA',
        'releaseDate': '2026-09-21T15:00:00Z',
      }));

      final result = await OtaUpdateService().checkForUpdates(
        overrideCurrentVersion: '1.1.7',
      );

      expect(result.hasUpdate, isTrue);
      expect(result.packageInfo, isNotNull);
      expect(
        result.packageInfo!.version,
        equals(SemanticVersion.tryParse('1.2.0')),
      );
      expect(
        result.packageInfo!.releaseNotes,
        contains('Bản cập nhật lớn'),
      );

      // Check when current version is already higher or equal
      final upToDateResult = await OtaUpdateService().checkForUpdates(
        overrideCurrentVersion: '1.2.0',
      );
      expect(upToDateResult.hasUpdate, isFalse);
    });

    test('checkForUpdates rejects a manifest without SHA-256', () async {
      final mockServer = Directory('${tempDir.path}/mock_server')..createSync();
      OtaUpdateService().setCustomServerDirForTesting(mockServer);
      File('${mockServer.path}/JA_WiFi_Manager_v1.2.0_Windows_x64.zip')
          .writeAsStringSync('fixture_zip_content');
      File('${mockServer.path}/version.json').writeAsStringSync(jsonEncode({
        'version': '1.2.0',
        'fileName': 'JA_WiFi_Manager_v1.2.0_Windows_x64.zip',
      }));

      final result = await OtaUpdateService().checkForUpdates(
        overrideCurrentVersion: '1.1.7',
      );

      expect(result.hasUpdate, isFalse);
      expect(result.errorMessage, contains('SHA-256'));
    });

    test('validatePackageForTesting rejects a tampered package', () async {
      final packageFile = File('${tempDir.path}/update.zip')
        ..writeAsStringSync('original-content');
      final expectedHash =
          await OtaUpdateService().calculateSha256ForTesting(packageFile);
      packageFile.writeAsStringSync('tampered-content');

      final package = UpdatePackageInfo(
        version: SemanticVersion.tryParse('1.2.0')!,
        fileName: 'JA_WiFi_Manager_v1.2.0_Windows_x64.zip',
        fullPath: packageFile.path,
        fileSize: await packageFile.length(),
        sha256: expectedHash,
      );

      expect(
        OtaUpdateService().validatePackageForTesting(package),
        throwsA(
          isA<StateError>().having(
            (error) => error.toString(),
            'message',
            contains('checksum mismatch'),
          ),
        ),
      );
    });
  });
}
