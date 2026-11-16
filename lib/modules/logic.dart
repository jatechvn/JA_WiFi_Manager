// lib/modules/logic.dart
// Core business logic facade for WiFi Hotspot Whitelist Guard (Dart Native Loop).

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'app_config.dart';
import 'models/wifi_models.dart';
import 'native/win_core.dart';
import 'services/app_power_manager.dart';
import 'native/win_ics_service.dart';
import 'utils.dart';
import 'utils/atomic_file_store.dart';

export 'models/wifi_models.dart';

part 'logic_logs_admin_part.dart';
part 'logic_device_store_part.dart';
part 'logic_blacklist_part.dart';
part 'logic_guard_engine_part.dart';
part 'logic_scanner_part.dart';
part 'logic_hotspot_part.dart';

final _logger = Logger('Logic');

String _escapePowerShellSingleQuoted(String value) {
  return value.replaceAll("'", "''");
}

String _mapNeighborStateLabel(String stateCode) {
  switch (stateCode) {
    case '6':
      return 'Reachable';
    case '5':
      return 'Stale';
    case '7':
      return 'Permanent';
    case '4':
      return 'Delay';
    case '3':
      return 'Probe';
    default:
      return 'Unknown';
  }
}

abstract class _WifiGuardLogicBase extends ChangeNotifier {
  List<WhitelistEntry> _whitelist = [];
  List<BlacklistEntry> _blacklist = [];
  Map<String, String> _customNicknames = {};
  List<ClientDevice> _connectedClients = [];
  final Map<String, String> _blockedIpToRealMac = {};
  final Set<String> _resolvingMacs = {};
  final Map<String, String> _resolvedHostnames = {};

  Timer? _guardLoopTimer;
  bool _isGuardActive = false;
  String _statusMessage = 'Guard is inactive.';
  int _checkIntervalSeconds = 5;
  String _searchQuery = '';

  List<String> _logLines = [];
  HotspotConfig? _hotspotConfig;

  _WifiGuardLogicBase({
    this.nativeCommand,
    this.nativeIcsRepair,
    this.hotspotCommandTimeout = const Duration(seconds: 30),
    this.nativeCommandTimeout = const Duration(seconds: 12),
  });

  final Duration hotspotCommandTimeout;
  final Duration nativeCommandTimeout;
  final Future<ProcessResult> Function(String, List<String>)? nativeCommand;
  final NativeIcsRepairFn? nativeIcsRepair;

  bool _hotspotOperationInProgress = false;
  bool get isHotspotBusy => _hotspotOperationInProgress;
  HotspotBusyStatus? _hotspotBusyStatus;
  HotspotBusyStatus? get hotspotBusyStatus => _hotspotBusyStatus;
  String? _icsRepairError;
  String? get icsRepairError => _icsRepairError;

  Future<void> _logIoChain = Future<void>.value();

  bool _isGuardCheckInProgress = false;
  bool _pendingGuardCheck = false;
  Completer<void>? _activeGuardCheckCompleter;
  bool get isGuardCheckInProgress => _isGuardCheckInProgress;

  bool _isScanInProgress = false;
  Completer<void>? _activeScanCompleter;

  bool _userManuallyStoppedHotspot = false;
  DateTime? _lastHotspotAutoHealAttempt;
  bool get userManuallyStoppedHotspot => _userManuallyStoppedHotspot;

  @override
  void dispose() {
    _isGuardActive = false;
    _guardLoopTimer?.cancel();
    _guardLoopTimer = null;
    super.dispose();
  }

  void _setHotspotPhase(
    String phaseKey, {
    int? stepIndex,
    int? totalSteps,
  }) {
    final current = _hotspotBusyStatus;
    if (current == null) return;
    _hotspotBusyStatus = current.copyWith(
      phaseKey: phaseKey,
      stepIndex: stepIndex,
      totalSteps: totalSteps,
    );
    notifyListeners();
  }

  Future<bool> _exclusiveHotspot(
    Future<bool> Function() operation, {
    HotspotOperationType type = HotspotOperationType.toggle,
    int totalSteps = 1,
    String initialPhase = 'starting',
  }) async {
    if (_hotspotOperationInProgress) return false;
    _hotspotOperationInProgress = true;
    _hotspotBusyStatus = HotspotBusyStatus(
      type: type,
      stepIndex: 1,
      totalSteps: totalSteps,
      phaseKey: initialPhase,
      startedAt: DateTime.now(),
    );
    AppPowerManager.instance.beginInteractiveOperation();
    notifyListeners();
    try {
      return await operation();
    } finally {
      _hotspotOperationInProgress = false;
      _hotspotBusyStatus = null;
      AppPowerManager.instance.endInteractiveOperation();
      notifyListeners();
    }
  }

  /// Bound only Hotspot commands; Guard/OTA timers and commands are independent.
  Future<ProcessResult> _runHotspotNative(
    String executable,
    List<String> arguments, {
    bool runInShell = false,
    Duration? timeout,
  }) =>
      _runNative(
        executable,
        arguments,
        runInShell: runInShell,
        timeout: timeout ?? hotspotCommandTimeout,
      );

  Future<ProcessResult> _runNative(
    String executable,
    List<String> arguments, {
    bool runInShell = false,
    Duration? timeout,
  }) async {
    final deadline = timeout ?? nativeCommandTimeout;
    if (nativeCommand != null) {
      return nativeCommand!(executable, arguments).timeout(deadline);
    }
    final process =
        await Process.start(executable, arguments, runInShell: runInShell);
    final output = process.stdout.transform(systemEncoding.decoder).join();
    final errors = process.stderr.transform(systemEncoding.decoder).join();
    final completed = Future.wait<Object>([process.exitCode, output, errors]);
    try {
      final values = await completed.timeout(deadline);
      return ProcessResult(process.pid, values[0] as int, values[1], values[2]);
    } on TimeoutException {
      process.kill();
      try {
        await process.exitCode.timeout(const Duration(seconds: 2));
      } catch (_) {
        _logger
            .warning('Native command $executable did not exit after timeout');
      }
      rethrow;
    }
  }

  Future<void> _runBounded(
    String executable,
    List<String> arguments, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (nativeCommand != null) {
      await nativeCommand!(executable, arguments);
      return;
    }
    final process = await Process.start(executable, arguments);
    try {
      await process.exitCode.timeout(timeout);
    } on TimeoutException {
      process.kill();
      _logger.warning('Killed hung $executable after ${timeout.inSeconds}s');
    }
  }

  List<WhitelistEntry> get whitelist => _whitelist;
  List<BlacklistEntry> get blacklist => _blacklist;
  Map<String, String> get customNicknames => _customNicknames;
  List<ClientDevice> get connectedClients => _connectedClients;
  bool get isGuardActive => _isGuardActive;
  String get statusMessage => _statusMessage;
  List<String> get logLines => _logLines;
  int get checkIntervalSeconds => _checkIntervalSeconds;
  String get searchQuery => _searchQuery;
  HotspotConfig? get hotspotConfig => _hotspotConfig;

  @visibleForTesting
  void setMonitorStateForTesting({
    required List<ClientDevice> clients,
    required bool isGuardActive,
  }) {
    _connectedClients = List.unmodifiable(clients);
    _isGuardActive = isGuardActive;
    notifyListeners();
  }

  @visibleForTesting
  void setHotspotConfigForTesting(HotspotConfig? config) {
    _hotspotConfig = config;
    notifyListeners();
  }

  @visibleForTesting
  void setHotspotBusyStatusForTesting(HotspotBusyStatus? status) {
    _hotspotBusyStatus = status;
    _hotspotOperationInProgress = status != null;
    notifyListeners();
  }

  @visibleForTesting
  void setBlacklistForTesting(List<BlacklistEntry> entries) {
    _blacklist = List.unmodifiable(entries);
    notifyListeners();
  }

  @visibleForTesting
  void setWhitelistForTesting(List<WhitelistEntry> entries) {
    _whitelist = List.unmodifiable(entries);
    notifyListeners();
  }

  @visibleForTesting
  void setCustomNicknamesForTesting(Map<String, String> nicknames) {
    _customNicknames = Map.from(nicknames);
    notifyListeners();
  }

  /// Returns whitelisted entries matching the search query
  List<WhitelistEntry> get filteredWhitelist {
    if (_searchQuery.trim().isEmpty) return _whitelist;
    final q = _searchQuery.toLowerCase().trim();
    return _whitelist
        .where((e) =>
            e.mac.toLowerCase().contains(q) ||
            e.nickname.toLowerCase().contains(q))
        .toList();
  }

  /// Returns blacklisted entries matching the search query
  List<BlacklistEntry> get filteredBlacklist {
    if (_searchQuery.trim().isEmpty) return _blacklist;
    final q = _searchQuery.toLowerCase().trim();
    return _blacklist
        .where((e) =>
            e.mac.toLowerCase().contains(q) ||
            e.nickname.toLowerCase().contains(q) ||
            e.reason.toLowerCase().contains(q))
        .toList();
  }

  /// Returns connected clients matching the search query
  List<ClientDevice> get filteredConnectedClients {
    if (_searchQuery.trim().isEmpty) return _connectedClients;
    final q = _searchQuery.toLowerCase().trim();
    return _connectedClients
        .where((e) =>
            e.ip.toLowerCase().contains(q) ||
            e.mac.toLowerCase().contains(q) ||
            e.nickname.toLowerCase().contains(q))
        .toList();
  }

  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    notifyListeners();
  }

  void setCheckInterval(int seconds) {
    if (_checkIntervalSeconds == seconds) return;
    _checkIntervalSeconds = seconds;
    AppConfig.set('check_interval_seconds', seconds.toString());

    // Restart loop timer if guard is active
    if (_isGuardActive && _guardLoopTimer != null) {
      _guardLoopTimer!.cancel();
      _guardLoopTimer = Timer.periodic(Duration(seconds: _checkIntervalSeconds),
          (timer) async {
        if (!_isGuardActive) {
          timer.cancel();
          return;
        }
        await _runGuardCheck();
      });
      _logger.info(
          'Restarted guard check loop with new interval: $seconds seconds');
    }
    notifyListeners();
  }

  /// Initialize: check admin, load configurations
  Future<void> initialize() async {
    _logger.info('Initializing WifiGuardLogic...');
    await writeLog(
        'App launched${AppConfig.isDebugMode ? ' (-debug mode)' : ''}',
        level: 'INFO');
    _checkIntervalSeconds = int.tryParse(
            AppConfig.get('check_interval_seconds', defaultValue: '5')) ??
        5;
    await loadDeviceNames();
    await loadWhitelist();
    await loadBlacklist();
    await rebuildSessionStateFromLog();
    await readLogLines();
    await fetchHotspotConfig();
  }

  // Cross-mixin contracts implemented by domain parts:
  Future<void> loadDeviceNames();
  Future<void> saveDeviceNames();
  Future<void> loadWhitelist();
  Future<void> saveWhitelist();
  Future<void> loadBlacklist();
  Future<void> saveBlacklist();
  bool isWhitelisted(String mac);
  bool isBlacklisted(String mac);
  BlacklistEntry? _getBlacklistEntry(String mac);
  String getEffectiveNickname(String mac, {String? defaultName});
  Future<void> _resolveAndSetNickname(String mac, String ip);
  Future<bool> addWhitelistDevice(String mac, String nickname);
  Future<void> removeWhitelistDevice(String mac);
  Future<bool> addBlacklistDevice(String mac, String nickname,
      {String reason = ''});
  Future<void> removeBlacklistDevice(String mac);
  Future<void> _enforceBlacklistBlock(String mac);
  Future<void> _unblockDeviceIfBlocked(String mac);
  Future<void> _runGuardCheck();
  Future<void> scanConnectedClients();
  List<ClientDevice> _dedupeByMac(List<ClientDevice> list);
  Future<void> readLogLines();
  Future<void> writeLog(String message, {String level = 'INFO'});
  Future<void> saveBlockedSession();
  Future<void> rebuildSessionStateFromLog();
  Future<void> fetchHotspotConfig();
  Future<bool> repairIcsService({bool silent = false});
  Future<bool> setHotspotState(bool enable, {bool isUserInitiated = true});
}

class WifiGuardLogic extends _WifiGuardLogicBase
    with
        _WifiLogsAdminMixin,
        _WifiDeviceStoreMixin,
        _WifiBlacklistMixin,
        _WifiGuardEngineMixin,
        _WifiScannerMixin,
        _WifiHotspotMixin {
  WifiGuardLogic({
    super.nativeCommand,
    super.nativeIcsRepair,
    super.hotspotCommandTimeout = const Duration(seconds: 30),
    super.nativeCommandTimeout = const Duration(seconds: 12),
  });
}
