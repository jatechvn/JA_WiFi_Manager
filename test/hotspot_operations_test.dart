import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ja_wifi_manager/modules/logic.dart';

class _TestLogic extends WifiGuardLogic {
  _TestLogic({
    required super.nativeCommand,
    super.nativeIcsRepair,
    super.hotspotCommandTimeout,
  });
  int refreshes = 0;
  final List<String> messages = [];

  @override
  Future<void> fetchHotspotConfig() async => refreshes++;

  @override
  Future<void> writeLog(String message, {String level = 'INFO'}) async {
    messages.add(message);
  }
}

void main() {
  test('ICS structured error preserves failing step and clears after success',
      () async {
    var psCalls = 0;
    var icsCalls = 0;
    final logic = _TestLogic(
      nativeCommand: (_, __) async {
        psCalls++;
        return ProcessResult(1, 0, '', '');
      },
      nativeIcsRepair: (
          {timeout = const Duration(seconds: 60), onProgressStep}) async {
        icsCalls++;
        if (icsCalls == 1) {
          return {
            'Ok': false,
            'ServicesRecovered': false,
            'HotspotState': 'InTransition',
            'Step': 'Wait Hotspot stable',
            'Error': 'Hotspot still InTransition after 30 seconds',
          };
        }
        onProgressStep?.call('Verify services Running');
        return {
          'Ok': true,
          'ServicesRecovered': true,
          'HotspotState': 'Off',
          'Config': {
            'Ssid': 'JA_Lab',
            'Passphrase': 'pass1234',
            'Band': 'FiveGigahertz',
            'State': 'Disabled',
            'MaxClients': 8,
            'ClientCount': 0,
          },
        };
      },
    );
    expect(await logic.repairIcsService(), isFalse);
    expect(logic.icsRepairError,
        '[Wait Hotspot stable] Hotspot still InTransition after 30 seconds');
    expect(logic.messages.last, contains('Wait Hotspot stable'));
    expect(psCalls, 0);
    expect(icsCalls, 1);

    expect(await logic.repairIcsService(), isTrue);
    expect(logic.icsRepairError, isNull);
    expect(psCalls, 0);
    expect(logic.refreshes, 0);
    expect(logic.hotspotConfig?.ssid, 'JA_Lab');
    expect(logic.hotspotConfig?.band, 'FiveGigahertz');
    logic.dispose();
  });

  test('ICS native timeout is distinct from service restart failure', () async {
    var psCalls = 0;
    final logic = _TestLogic(
      hotspotCommandTimeout: const Duration(milliseconds: 5),
      nativeCommand: (_, __) async {
        psCalls++;
        return ProcessResult(1, 0, '', '');
      },
      nativeIcsRepair: (
              {timeout = const Duration(seconds: 60), onProgressStep}) =>
          Completer<Map<String, dynamic>>().future,
    );
    expect(await logic.repairIcsService(), isFalse);
    expect(psCalls, 0);
    expect(logic.icsRepairError, startsWith('[Repair helper timeout]'));
    expect(logic.isHotspotBusy, isFalse);
    logic.dispose();
  });

  test('ICS response rejects malformed or still-transitioning results',
      () async {
    for (final response in <Map<String, dynamic>>[
      {},
      {'Ok': true, 'ServicesRecovered': true, 'HotspotState': 'InTransition'},
      {'Ok': true, 'ServicesRecovered': false, 'HotspotState': 'Off'},
    ]) {
      var psCalls = 0;
      final logic = _TestLogic(
        nativeCommand: (_, __) async {
          psCalls++;
          return ProcessResult(1, 0, '', '');
        },
        nativeIcsRepair: (
                {timeout = const Duration(seconds: 60),
                onProgressStep}) async =>
            response,
      );
      expect(await logic.repairIcsService(), isFalse);
      expect(psCalls, 0);
      expect(logic.isHotspotBusy, isFalse);
      logic.dispose();
    }
  });

  test('Normal enable starts tethering without any ICS reset or PID kill',
      () async {
    final commands = <String>[];
    final capturedArgs = <List<String>>[];
    final logic = _TestLogic(nativeCommand: (_, args) async {
      capturedArgs.add(List<String>.from(args));
      commands.add(args.last);
      return ProcessResult(1, 0, 'Success', '');
    });
    expect(await logic.setHotspotState(true), isTrue);
    expect(commands, hasLength(1));
    expect(capturedArgs.single, isNot(contains('-WindowStyle')));
    expect(capturedArgs.single, isNot(contains('-NonInteractive')));
    expect(commands.single, contains('StartTetheringAsync'));
    expect(commands.single, isNot(contains('SharedAccess')));
    expect(commands.single, isNot(contains('taskkill')));
    expect(commands.single, isNot(contains('Wait(-1)')));
    expect(commands.single, contains('Wait(20000)'));
    expect(commands.single, contains('Cancel()'));
    expect(logic.refreshes, 1);
    expect(logic.isHotspotBusy, isFalse);
    logic.dispose();
  });

  test('One shared lock rejects toggle, repair, DHCP and config overlap',
      () async {
    final pending = Completer<ProcessResult>();
    var calls = 0;
    final logic = _TestLogic(nativeCommand: (_, __) {
      calls++;
      return pending.future;
    });
    final operation = logic.setHotspotState(true);
    expect(logic.isHotspotBusy, isTrue);
    expect(await logic.setHotspotState(false), isFalse);
    expect(await logic.repairIcsService(), isFalse);
    expect(await logic.fixHotspotDhcp(), isFalse);
    expect(await logic.updateHotspotConfig('test', 'password', 'Auto', 8),
        isFalse);
    expect(calls, 1);
    pending.complete(ProcessResult(1, 0, 'Success', ''));
    expect(await operation, isTrue);
    expect(logic.isHotspotBusy, isFalse);
    logic.dispose();
  });

  test('Timeout releases UI busy state and late result cannot report success',
      () async {
    final pending = Completer<ProcessResult>();
    var calls = 0;
    final logic = _TestLogic(
      hotspotCommandTimeout: const Duration(milliseconds: 20),
      nativeCommand: (_, __) => ++calls == 1
          ? pending.future
          : Future.value(ProcessResult(1, 0, 'AlreadyOff', '')),
    );
    expect(await logic.setHotspotState(true), isFalse);
    expect(logic.isHotspotBusy, isFalse);
    pending.complete(ProcessResult(1, 0, 'Success', ''));
    await Future<void>.delayed(Duration.zero);
    expect(logic.refreshes, 0);
    expect(logic.messages, isEmpty);
    expect(await logic.setHotspotState(false), isTrue);
    logic.dispose();
  });

  test('Native failure/exception releases lock; repair never kills host PID',
      () async {
    var psCalls = 0;
    final logic = _TestLogic(
      nativeCommand: (_, __) async {
        psCalls++;
        return ProcessResult(1, 1, 'Failure', 'tethering error');
      },
      nativeIcsRepair:
          ({timeout = const Duration(seconds: 60), onProgressStep}) async => {
        'Ok': false,
        'ServicesRecovered': false,
        'HotspotState': 'Unknown',
        'Step': 'Stop SharedAccess',
        'Error':
            'SharedAccess timed out in StopPending (terminated kill avoided)',
      },
    );
    expect(await logic.repairIcsService(), isFalse);
    expect(psCalls, 0);
    expect(logic.isHotspotBusy, isFalse);
    expect(await logic.setHotspotState(true), isFalse);
    logic.dispose();

    final throwingIcs = _TestLogic(
      nativeCommand: (_, __) async => ProcessResult(1, 0, '', ''),
      nativeIcsRepair: (
              {timeout = const Duration(seconds: 60), onProgressStep}) async =>
          throw StateError('native channel failure'),
    );
    expect(await throwingIcs.repairIcsService(), isFalse);
    expect(throwingIcs.isHotspotBusy, isFalse);
    throwingIcs.dispose();

    final throwing = _TestLogic(
        nativeCommand: (_, __) async => throw StateError('native failure'));
    expect(await throwing.setHotspotState(true), isFalse);
    expect(throwing.isHotspotBusy, isFalse);
    throwing.dispose();
  });

  test('DHCP repair aborts if hotspot stop cannot be confirmed', () async {
    final commands = <String>[];
    final logic = _TestLogic(nativeCommand: (_, args) async {
      commands.add(args.last);
      return ProcessResult(1, 1, 'Failure', '');
    });
    expect(await logic.fixHotspotDhcp(), isFalse);
    expect(commands, hasLength(1));
    expect(commands.single, contains('StopTetheringAsync'));
    expect(logic.isHotspotBusy, isFalse);
    logic.dispose();
  });

  test('DHCP internal sequence uses one lock without deadlocking itself',
      () async {
    final commands = <String>[];
    var icsCalls = 0;
    final logic = _TestLogic(
      nativeCommand: (_, args) async {
        commands.add(args.last);
        return ProcessResult(1, 0, commands.length == 1 ? 'Success' : '', '');
      },
      nativeIcsRepair: (
          {timeout = const Duration(seconds: 60), onProgressStep}) async {
        icsCalls++;
        return {
          'Ok': true,
          'ServicesRecovered': true,
          'HotspotState': 'Off',
        };
      },
    );
    expect(await logic.fixHotspotDhcp(), isTrue);
    expect(icsCalls, 1);
    expect(commands, hasLength(2));
    expect(logic.isHotspotBusy, isFalse);
    logic.dispose();
  });
}
