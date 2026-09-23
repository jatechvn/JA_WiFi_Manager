// lib/modules/logic.dart
// Core business logic coordinator for WiFi Hotspot Whitelist Guard (Dart Native Loop)

import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'utils.dart';
import 'app_config.dart';
import 'native/win_core.dart';

final _logger = Logger('Logic');

String _escapePowerShellSingleQuoted(String value) {
  return value.replaceAll("'", "''");
}

class WhitelistEntry {
  final String mac;
  String nickname;

  WhitelistEntry({required this.mac, required this.nickname});

  Map<String, dynamic> toJson() => {
        'mac': mac,
        'nickname': nickname,
      };
}

class ClientDevice {
  final String ip;
  final String mac;
  final String state;
  final String nickname;
  final bool isAllowed;
  final bool isWhitelisted;
  final bool isBlocked;

  ClientDevice({
    required this.ip,
    required this.mac,
    required this.state,
    required this.nickname,
    required this.isAllowed,
    required this.isWhitelisted,
    required this.isBlocked,
  });
}

class HotspotConfig {
  final String ssid;
  final String passphrase;
  final String band; // Auto, TwoPointFourGigahertz, FiveGigahertz, SixGigahertz
  final String state; // Disabled, Enabling, Enabled, Disabling, Failed
  final int maxClients;
  final int clientCount;

  HotspotConfig({
    required this.ssid,
    required this.passphrase,
    required this.band,
    required this.state,
    required this.maxClients,
    required this.clientCount,
  });

  factory HotspotConfig.fromJson(Map<String, dynamic> json) {
    return HotspotConfig(
      ssid: json['Ssid']?.toString() ?? '',
      passphrase: json['Passphrase']?.toString() ?? '',
      band: json['Band']?.toString() ?? 'Auto',
      state: json['State']?.toString() ?? 'Disabled',
      maxClients: json['MaxClients'] as int? ?? 8,
      clientCount: json['ClientCount'] as int? ?? 0,
    );
  }
}

class WifiGuardLogic extends ChangeNotifier {
  List<WhitelistEntry> _whitelist = [];
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

  WifiGuardLogic();

  List<WhitelistEntry> get whitelist => _whitelist;
  List<ClientDevice> get connectedClients => _connectedClients;
  bool get isGuardActive => _isGuardActive;
  String get statusMessage => _statusMessage;
  List<String> get logLines => _logLines;
  int get checkIntervalSeconds => _checkIntervalSeconds;
  String get searchQuery => _searchQuery;

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

  HotspotConfig? get hotspotConfig => _hotspotConfig;

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
    await loadWhitelist();
    await rebuildSessionStateFromLog();
    await readLogLines();
    await fetchHotspotConfig();
  }

  /// Check if process is running as Administrator
  Future<bool> isAdmin() async {
    if (Platform.isWindows) {
      return WindowsNativeEngine.isAdmin();
    }
    return true; // Stub for other platforms
  }

  /// Request Administrator elevation, forwarding the original launch [args]
  /// (e.g. `-debug`) so they aren't lost on the elevated relaunch.
  Future<void> elevateAdmin(List<String> args) async {
    if (Platform.isWindows) {
      await WindowsNativeEngine.elevateAdmin(args);
    }
  }

  Future<bool> getIsStartupEnabled() async {
    if (!Platform.isWindows) return false;
    try {
      final result = await Process.run(
          'powershell',
          [
            '-NoProfile',
            '-Command',
            '(Get-ItemProperty -Path "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Run" -Name "JAWiFiGuard" -ErrorAction SilentlyContinue) -ne \$null'
          ],
          runInShell: false);
      return result.stdout.toString().trim().toLowerCase() == 'true';
    } catch (_) {
      return false;
    }
  }

  Future<void> setStartupEnabled(bool enable) async {
    if (!Platform.isWindows) return;
    try {
      if (enable) {
        final exePath = Platform.resolvedExecutable;
        await Process.run(
            'powershell',
            [
              '-NoProfile',
              '-Command',
              'Set-ItemProperty -Path "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Run" -Name "JAWiFiGuard" -Value "\\"$exePath\\" --minimized"'
            ],
            runInShell: false);
      } else {
        await Process.run(
            'powershell',
            [
              '-NoProfile',
              '-Command',
              'Remove-ItemProperty -Path "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Run" -Name "JAWiFiGuard" -ErrorAction SilentlyContinue'
            ],
            runInShell: false);
      }
    } catch (_) {}
  }

  // ─── Whitelist Management ─────────────────────────────────────────────────

  Future<void> loadWhitelist() async {
    try {
      final file = File(AppConfig.getWhitelistPath());
      if (!file.existsSync()) {
        _whitelist = [
          WhitelistEntry(
              mac: 'D0-65-78-C4-00-9F', nickname: 'Default Allowed 1'),
          WhitelistEntry(
              mac: 'D0-65-78-D4-57-83', nickname: 'Default Allowed 2'),
        ];
        await saveWhitelist();
        return;
      }
      final content = file.readAsStringSync();
      if (content.trim().isEmpty) {
        _whitelist = [];
        return;
      }
      final decoded = jsonDecode(content);
      final List<dynamic> list = decoded is List ? decoded : [decoded];
      _whitelist = list
          .map((item) {
            return WhitelistEntry(
              mac: normalizeMacAddress(item['mac']?.toString() ?? ''),
              nickname: item['nickname']?.toString() ?? '',
            );
          })
          .where((e) => e.mac.isNotEmpty)
          .toList();
      notifyListeners();
    } catch (e) {
      _logger.warning('Failed to load whitelist: $e');
      _whitelist = [];
    }
  }

  Future<void> saveWhitelist() async {
    try {
      final file = File(AppConfig.getWhitelistPath());
      final jsonList = _whitelist.map((e) => e.toJson()).toList();
      file.writeAsStringSync(jsonEncode(jsonList));
      notifyListeners();
    } catch (e) {
      _logger.severe('Failed to save whitelist: $e');
    }
  }

  Future<String> _resolveHostname(String ip) async {
    if (ip.isEmpty) return '';

    // 1. Try Dart's native reverse DNS lookup
    try {
      final lookup = await InternetAddress(ip)
          .reverse()
          .timeout(const Duration(milliseconds: 800));
      if (lookup.host.isNotEmpty && lookup.host != ip) {
        return lookup.host;
      }
    } catch (_) {}

    // 2. Try NetBIOS lookup via nbtstat -A
    try {
      final result = await Process.run('nbtstat', ['-A', ip])
          .timeout(const Duration(milliseconds: 1500));
      final output = result.stdout.toString();
      for (var line in output.split('\n')) {
        final match = RegExp(r'^\s*([A-Za-z0-9_-]+)\s*<00>\s*UNIQUE',
                caseSensitive: false)
            .firstMatch(line);
        if (match != null) {
          final name = match.group(1)?.trim();
          if (name != null && name.isNotEmpty) {
            return name;
          }
        }
      }
    } catch (_) {}

    // 3. Try PowerShell lookup as a fallback
    try {
      final result = await Process.run(
              'powershell',
              [
                '-NoProfile',
                '-Command',
                '[System.Net.Dns]::GetHostEntry("$ip").HostName'
              ],
              runInShell: false)
          .timeout(const Duration(milliseconds: 1500));

      final host = result.stdout.toString().trim();
      if (host.isNotEmpty && !host.contains('error') && host != ip) {
        return host;
      }
    } catch (_) {}

    return '';
  }

  Future<void> _resolveAndSetNickname(String mac, String ip) async {
    final normalized = normalizeMacAddress(mac);
    if (_resolvingMacs.contains(normalized)) return;
    _resolvingMacs.add(normalized);

    try {
      final resolved = await _resolveHostname(ip);
      if (resolved.isNotEmpty) {
        _resolvedHostnames[normalized] = resolved;

        // Find and update in whitelist
        for (final entry in _whitelist) {
          if (normalizeMacAddress(entry.mac) == normalized) {
            if (entry.nickname.isEmpty ||
                entry.nickname.startsWith('Device_')) {
              final oldName = entry.nickname;
              entry.nickname = resolved;
              await saveWhitelist();
              await writeLog(
                  'Auto-resolved client nickname: MAC=$mac ($oldName -> $resolved)',
                  level: 'OK');
            }
            break;
          }
        }
        notifyListeners();
      }
    } finally {
      _resolvingMacs.remove(normalized);
    }
  }

  Future<bool> addWhitelistDevice(String mac, String nickname) async {
    final normalized = normalizeMacAddress(mac);
    if (!isValidMacAddress(normalized)) return false;

    // Check if exists
    final exists = _whitelist.any((e) => e.mac == normalized);
    if (exists) return false;

    String finalNickname = nickname.trim();
    if (finalNickname.isEmpty) {
      // Check if currently connected
      ClientDevice? connected;
      for (final c in _connectedClients) {
        if (normalizeMacAddress(c.mac) == normalized) {
          connected = c;
          break;
        }
      }

      if (connected != null) {
        final resolved = await _resolveHostname(connected.ip);
        finalNickname = resolved.isNotEmpty
            ? resolved
            : 'Device_${normalized.replaceAll('-', '').substring(8)}';
      } else {
        finalNickname = 'Device_${normalized.replaceAll('-', '').substring(8)}';
      }
    }

    _whitelist.add(WhitelistEntry(mac: normalized, nickname: finalNickname));
    await saveWhitelist();
    _logger.info('Added to whitelist: $normalized ($finalNickname)');
    return true;
  }

  Future<void> removeWhitelistDevice(String mac) async {
    final normalized = normalizeMacAddress(mac);
    _whitelist.removeWhere((e) => e.mac == normalized);
    await saveWhitelist();
    _logger.info('Removed from whitelist: $normalized');
  }

  Future<void> editDeviceNickname(String mac, String newNickname) async {
    final normalized = normalizeMacAddress(mac);
    for (final entry in _whitelist) {
      if (entry.mac == normalized) {
        entry.nickname = newNickname;
        break;
      }
    }
    await saveWhitelist();
    _logger.info('Updated nickname: $normalized -> $newNickname');
  }

  WhitelistEntry? _getWhitelistEntry(String mac) {
    final normalized = normalizeMacAddress(mac);
    for (final entry in _whitelist) {
      if (entry.mac == normalized) return entry;
    }
    return null;
  }

  // ─── Guard Controls (Dart Native Loop) ────────────────────────────────────

  Future<void> startGuard() async {
    if (_isGuardActive) return;

    _logger.info('Starting WiFi Hotspot Guard native loop...');
    _isGuardActive = true;
    _statusMessage = 'Guard is active. Monitoring clients...';
    notifyListeners();

    try {
      await writeLog('====== WiFi Guard v4 (Dart loop) started ======',
          level: 'INFO');
      await _cleanupOldRules();

      // Run check loop periodically
      _guardLoopTimer = Timer.periodic(Duration(seconds: _checkIntervalSeconds),
          (timer) async {
        if (!_isGuardActive) {
          timer.cancel();
          return;
        }
        await _runGuardCheck();
      });

      // Immediate run
      await _runGuardCheck();
    } catch (e) {
      _logger.severe('Failed to start WiFi Guard loop: $e');
      _isGuardActive = false;
      _statusMessage = 'Failed to start: $e';
      notifyListeners();
    }
  }

  Future<void> stopGuard() async {
    if (!_isGuardActive) return;
    _isGuardActive = false;
    _guardLoopTimer?.cancel();
    _guardLoopTimer = null;

    _statusMessage = 'Stopping Guard...';
    notifyListeners();

    try {
      await writeLog('====== WiFi Guard stopped and cleaned ======',
          level: 'WARN');
      await _cleanupOldRules();

      _blockedIpToRealMac.clear();
      _connectedClients.clear();
      _statusMessage = 'Guard is inactive.';
      notifyListeners();
    } catch (e) {
      _logger.severe('Error stopping Guard: $e');
      _statusMessage = 'Error stopping: $e';
      notifyListeners();
    }
  }

  Future<void> _runGuardCheck() async {
    if (!Platform.isWindows) return;

    try {
      // Combined command: Get IP, index, adapter name, and neighbors in one single PowerShell call
      final combinedResult = await Process.run(
          'powershell',
          [
            '-NoProfile',
            '-ExecutionPolicy',
            'Bypass',
            '-Command',
            '\$ipEntry = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { \$_.IPAddress -like "192.168.137.*" } | Select-Object -First 1; if (\$ipEntry) { \$ifIndex = \$ipEntry.InterfaceIndex; \$adapterName = (Get-NetAdapter -InterfaceIndex \$ifIndex | Select-Object -ExpandProperty Name -First 1); \$neighbors = @(Get-NetNeighbor -InterfaceIndex \$ifIndex -ErrorAction SilentlyContinue | Where-Object { \$_.State -in @("Reachable", "Stale", "Permanent") -and \$_.LinkLayerAddress -notmatch "^(FF-FF-FF-FF-FF-FF|01-00-5E|33-33|00-00-00-00-00)" -and \$_.IPAddress -notmatch "^(224\\.|239\\.|255\\.)" } | Select-Object IPAddress, LinkLayerAddress, State); [PSCustomObject]@{ InterfaceIndex = \$ifIndex; AdapterName = \$adapterName; Neighbors = \$neighbors } | ConvertTo-Json -Depth 4 }'
          ],
          runInShell: false);

      final output = combinedResult.stdout.toString().trim();
      if (output.isEmpty || output == 'null') {
        await writeLog('Không tìm thấy Hotspot adapter. Chờ hotspot bật...',
            level: 'WARN');
        _statusMessage = 'Waiting for hotspot...';
        notifyListeners();
        return;
      }

      final Map<String, dynamic> decodedData = jsonDecode(output);
      final ifIndex = decodedData['InterfaceIndex'] as int?;
      final adapterName = decodedData['AdapterName']?.toString() ?? '';
      final dynamic neighborsVal = decodedData['Neighbors'];

      List<dynamic> jsonList = [];
      if (neighborsVal != null) {
        jsonList = neighborsVal is List ? neighborsVal : [neighborsVal];
      }

      if (jsonList.isEmpty) {
        _connectedClients = [];
        notifyListeners();
        return;
      }

      final wlMacs = _whitelist.map((e) => e.mac.toUpperCase()).toSet();
      final List<ClientDevice> currentClientsList = [];

      for (final item in jsonList) {
        final ip = item['IPAddress']?.toString() ?? '';
        final rawMac =
            normalizeMacAddress(item['LinkLayerAddress']?.toString() ?? '');
        final stateCode = item['State']?.toString() ?? '';

        if (ip.isEmpty || rawMac.isEmpty) continue;
        if (ip == '192.168.137.1') continue; // Gateway self

        bool isPoisoned = rawMac == '00-00-00-00-00-01';
        String realMac = rawMac;

        if (isPoisoned) {
          realMac = _blockedIpToRealMac[ip] ?? 'UNKNOWN-MAC';
        }

        final isWhitelisted = wlMacs.contains(realMac);

        if (isWhitelisted) {
          // If whitelisted but marked blocked in system, we must UNBLOCK it!
          if (isPoisoned || _blockedIpToRealMac.containsKey(ip)) {
            // Remove ARP poisoning
            await Process.run(
                'powershell',
                [
                  '-NoProfile',
                  '-Command',
                  'Remove-NetNeighbor -InterfaceIndex $ifIndex -IPAddress $ip -Confirm:\$false -ErrorAction SilentlyContinue'
                ],
                runInShell: false);

            // Remove Firewall Rule
            final ruleTag = ip.replaceAll('.', '-');
            await Process.run(
                'powershell',
                [
                  '-NoProfile',
                  '-Command',
                  'Remove-NetFirewallRule -DisplayName "WiFiGuard_${ruleTag}_IN" -ErrorAction SilentlyContinue'
                ],
                runInShell: false);

            _blockedIpToRealMac.remove(ip);
            isPoisoned = false;
            await writeLog('UNBLOCKED: MAC=$realMac  IP=$ip', level: 'OK');
          } else {
            await writeLog('ALLOWED : MAC=$realMac  IP=$ip', level: 'ALLOW');
          }
        } else {
          // Intruder detected!
          if (_blockedIpToRealMac.containsKey(ip) || isPoisoned) {
            // Re-enforce poison every iteration
            await Process.run(
                'powershell',
                [
                  '-NoProfile',
                  '-Command',
                  'Remove-NetNeighbor -InterfaceIndex $ifIndex -IPAddress $ip -Confirm:\$false -ErrorAction SilentlyContinue; New-NetNeighbor -InterfaceIndex $ifIndex -IPAddress $ip -LinkLayerAddress "00-00-00-00-00-01" -State Permanent -ErrorAction SilentlyContinue'
                ],
                runInShell: false);
          } else {
            // Brand new intruder -> Block!
            await writeLog('INTRUDER: MAC=$realMac  IP=$ip --> Blocking...',
                level: 'WARN');

            // 1. Poison ARP table
            await Process.run(
                'powershell',
                [
                  '-NoProfile',
                  '-Command',
                  'Remove-NetNeighbor -InterfaceIndex $ifIndex -IPAddress $ip -Confirm:\$false -ErrorAction SilentlyContinue; New-NetNeighbor -InterfaceIndex $ifIndex -IPAddress $ip -LinkLayerAddress "00-00-00-00-00-01" -State Permanent -ErrorAction SilentlyContinue'
                ],
                runInShell: false);

            // 2. Add Firewall blocking rule
            final ruleTag = ip.replaceAll('.', '-');
            await Process.run(
                'powershell',
                [
                  '-NoProfile',
                  '-Command',
                  'New-NetFirewallRule -DisplayName "WiFiGuard_${ruleTag}_IN" -Direction Inbound -Action Block -RemoteAddress $ip -InterfaceAlias "$adapterName" -Protocol Any -Enabled True -ErrorAction SilentlyContinue'
                ],
                runInShell: false);

            _blockedIpToRealMac[ip] = realMac;
            await writeLog(
                'BLOCKED: MAC=$realMac  IP=$ip  [ARP Poison + Firewall IN]',
                level: 'BLOCK');
          }
        }

        // Add to view list
        String stateLabel = 'Unknown';
        if (stateCode == '6') {
          stateLabel = 'Reachable';
        } else if (stateCode == '5') {
          stateLabel = 'Stale';
        } else if (stateCode == '7') {
          stateLabel = 'Permanent';
        } else if (stateCode == '4') {
          stateLabel = 'Delay';
        } else if (stateCode == '3') {
          stateLabel = 'Probe';
        }

        final wlEntry = _getWhitelistEntry(realMac);
        final cachedHostname = _resolvedHostnames[realMac] ?? '';
        if (cachedHostname.isEmpty) {
          _resolveAndSetNickname(realMac, ip);
        }

        String displayName = '';
        if (wlEntry != null &&
            wlEntry.nickname.isNotEmpty &&
            !wlEntry.nickname.startsWith('Device_')) {
          displayName = wlEntry.nickname;
        } else {
          displayName = cachedHostname.isNotEmpty
              ? cachedHostname
              : (wlEntry?.nickname ?? '');
        }

        currentClientsList.add(ClientDevice(
          ip: ip,
          mac: realMac,
          state: stateLabel,
          nickname: displayName,
          isAllowed: isWhitelisted,
          isWhitelisted: isWhitelisted,
          isBlocked: isPoisoned || _blockedIpToRealMac.containsKey(ip),
        ));
      }

      _connectedClients = _dedupeByMac(currentClientsList);
      _statusMessage = 'Guard is active. Monitoring hotspot clients.';
      notifyListeners();
    } catch (e) {
      _logger.severe('Exception in guard check: $e');
    }
  }

  Future<void> _cleanupOldRules() async {
    _logger.info('Cleaning up firewall rules and ARP poison table entries...');
    // Bounded so closing the window cannot wait on a stuck PowerShell host.
    await _runBounded(
      'powershell',
      [
        '-NoProfile',
        '-Command',
        'Get-NetFirewallRule -DisplayName "WiFiGuard_*" -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue',
      ],
    );
    await _runBounded(
      'powershell',
      [
        '-NoProfile',
        '-Command',
        'Remove-NetNeighbor -LinkLayerAddress "00-00-00-00-00-01" -Confirm:\$false -ErrorAction SilentlyContinue',
      ],
    );
  }

  Future<void> _runBounded(
    String executable,
    List<String> arguments, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final process = await Process.start(executable, arguments);
    try {
      await process.exitCode.timeout(timeout);
    } on TimeoutException {
      process.kill();
      _logger.warning('Killed hung $executable after ${timeout.inSeconds}s');
    }
  }

  // ─── Connected Clients Scanner (Single pass query for Manual Refresh) ─────

  Future<void> scanConnectedClients() async {
    if (!Platform.isWindows) return;

    try {
      final combinedResult = await Process.run(
          'powershell',
          [
            '-NoProfile',
            '-ExecutionPolicy',
            'Bypass',
            '-Command',
            '\$ipEntry = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { \$_.IPAddress -like "192.168.137.*" } | Select-Object -First 1; if (\$ipEntry) { \$ifIndex = \$ipEntry.InterfaceIndex; \$neighbors = @(Get-NetNeighbor -InterfaceIndex \$ifIndex -ErrorAction SilentlyContinue | Where-Object { \$_.State -in @("Reachable", "Stale", "Permanent") -and \$_.LinkLayerAddress -notmatch "^(FF-FF-FF-FF-FF-FF|01-00-5E|33-33|00-00-00-00-00)" -and \$_.IPAddress -notmatch "^(224\\.|239\\.|255\\.)" } | Select-Object IPAddress, LinkLayerAddress, State); [PSCustomObject]@{ InterfaceIndex = \$ifIndex; Neighbors = \$neighbors } | ConvertTo-Json -Depth 4 }'
          ],
          runInShell: false);

      final output = combinedResult.stdout.toString().trim();
      if (output.isEmpty || output == 'null') {
        _connectedClients = [];
        notifyListeners();
        return;
      }

      final Map<String, dynamic> decodedData = jsonDecode(output);
      final dynamic neighborsVal = decodedData['Neighbors'];

      List<dynamic> jsonList = [];
      if (neighborsVal != null) {
        jsonList = neighborsVal is List ? neighborsVal : [neighborsVal];
      }

      final List<ClientDevice> list = [];
      for (final item in jsonList) {
        final ip = item['IPAddress']?.toString() ?? '';
        var rawMac =
            normalizeMacAddress(item['LinkLayerAddress']?.toString() ?? '');
        final stateCode = item['State']?.toString() ?? '';

        if (ip.isEmpty || rawMac.isEmpty) continue;
        if (ip == '192.168.137.1') continue;

        bool isPoisoned = rawMac == '00-00-00-00-00-01';
        String realMac = rawMac;

        if (isPoisoned) {
          realMac = _blockedIpToRealMac[ip] ?? 'UNKNOWN-MAC';
        }

        final wlEntry = _getWhitelistEntry(realMac);
        final cachedHostname = _resolvedHostnames[realMac] ?? '';
        if (cachedHostname.isEmpty) {
          _resolveAndSetNickname(realMac, ip);
        }

        String displayName = '';
        if (wlEntry != null &&
            wlEntry.nickname.isNotEmpty &&
            !wlEntry.nickname.startsWith('Device_')) {
          displayName = wlEntry.nickname;
        } else {
          displayName = cachedHostname.isNotEmpty
              ? cachedHostname
              : (wlEntry?.nickname ?? '');
        }
        final isAllowed = wlEntry != null && !isPoisoned;

        String stateLabel = 'Unknown';
        if (stateCode == '6') {
          stateLabel = 'Reachable';
        } else if (stateCode == '5') {
          stateLabel = 'Stale';
        } else if (stateCode == '7') {
          stateLabel = 'Permanent';
        } else if (stateCode == '4') {
          stateLabel = 'Delay';
        } else if (stateCode == '3') {
          stateLabel = 'Probe';
        }

        list.add(ClientDevice(
          ip: ip,
          mac: realMac,
          state: stateLabel,
          nickname: displayName,
          isAllowed: isAllowed,
          isWhitelisted: wlEntry != null,
          isBlocked: isPoisoned || _blockedIpToRealMac.containsKey(ip),
        ));
      }

      _connectedClients = _dedupeByMac(list);
      notifyListeners();
    } catch (e) {
      _logger.warning('Scan connected clients failed: $e');
    }
  }

  int _neighborPriority(ClientDevice client) {
    final isIPv4 = !client.ip.contains(':');
    int stateScore;
    switch (client.state) {
      case 'Reachable':
        stateScore = 5;
        break;
      case 'Stale':
        stateScore = 4;
        break;
      case 'Permanent':
        stateScore = 3;
        break;
      case 'Delay':
        stateScore = 2;
        break;
      case 'Probe':
        stateScore = 1;
        break;
      default:
        stateScore = 0;
    }
    return (isIPv4 ? 100 : 0) + stateScore;
  }

  // Get-NetNeighbor reports one row per (IP, MAC) pair, so a single device
  // shows up multiple times: once for its IPv6 link-local neighbor entry
  // and once for its IPv4 entry, plus stale leftover IPv4 entries from a
  // previous DHCP lease. Collapse to one row per MAC, keeping the most
  // useful entry (IPv4 over IPv6, Reachable over Stale/Delay/Probe).
  // Shared by every code path that builds the connected-clients list
  // (scanConnectedClients + the periodic _runGuardCheck loop) so a fix
  // here can't silently apply to only one of them again.
  List<ClientDevice> _dedupeByMac(List<ClientDevice> list) {
    final Map<String, ClientDevice> deduped = {};
    for (final client in list) {
      final existing = deduped[client.mac];
      if (existing == null ||
          _neighborPriority(client) > _neighborPriority(existing)) {
        deduped[client.mac] = client;
      }
    }
    return deduped.values.toList();
  }

  // ─── Log Management ───────────────────────────────────────────────────────

  Future<void> readLogLines() async {
    try {
      final logFile = File(AppConfig.getLogPath());
      if (!logFile.existsSync()) {
        _logLines = [];
        notifyListeners();
        return;
      }
      final lines = logFile.readAsLinesSync();
      if (lines.length > 200) {
        _logLines = lines.sublist(lines.length - 200);
      } else {
        _logLines = lines;
      }
      notifyListeners();
    } catch (e) {
      _logger.warning('Failed to read logs: $e');
    }
  }

  Future<void> writeLog(String message, {String level = 'INFO'}) async {
    final timestamp = formatTimestampDisplay();
    final line = '[$timestamp][$level] $message';
    _logLines.add(line);
    if (_logLines.length > 200) {
      _logLines.removeAt(0);
    }

    try {
      final logFile = File(AppConfig.getLogPath());
      if (!logFile.parent.existsSync()) {
        logFile.parent.createSync(recursive: true);
      }
      await logFile.writeAsString('$line\n',
          mode: FileMode.append, encoding: utf8);
      // Prune log file asynchronously if it grows too large
      _pruneLogFileIfNeeded(logFile);
    } catch (e) {
      _logger.warning('Failed to write log to file: $e');
    }
    notifyListeners();
  }

  Future<void> _pruneLogFileIfNeeded(File logFile) async {
    try {
      if (await logFile.exists()) {
        final length = await logFile.length();
        // If file size exceeds 1 MB
        if (length > 1024 * 1024) {
          final lines = await logFile.readAsLines();
          if (lines.length > 1000) {
            final prunedLines = lines.sublist(lines.length - 1000);
            await logFile.writeAsString('${prunedLines.join('\n')}\n',
                mode: FileMode.write, encoding: utf8);
            _logger.info('Log file pruned: kept last 1000 lines.');
          }
        }
      }
    } catch (e) {
      _logger.warning('Failed to prune log file: $e');
    }
  }

  Future<void> clearLogs() async {
    try {
      final logFile = File(AppConfig.getLogPath());
      if (logFile.existsSync()) {
        await logFile.writeAsString('');
      }
      _logLines = [];
      notifyListeners();
    } catch (e) {
      _logger.warning('Failed to clear logs: $e');
    }
  }

  Future<void> rebuildSessionStateFromLog() async {
    try {
      final logFile = File(AppConfig.getLogPath());
      if (!logFile.existsSync()) return;

      final lines = logFile.readAsLinesSync();
      for (final line in lines) {
        if (line.contains('[BLOCK]')) {
          final macMatch = RegExp(r'MAC=([0-9A-Fa-f-]{17})').firstMatch(line);
          final ipMatch = RegExp(r'IP=([0-9.]+)(?:\s|$)').firstMatch(line);
          if (macMatch != null && ipMatch != null) {
            _blockedIpToRealMac[ipMatch.group(1)!] = macMatch.group(1)!;
          }
        } else if (line.contains('UNBLOCKED')) {
          final ipMatch = RegExp(r'IP=([0-9.]+)(?:\s|$)').firstMatch(line);
          if (ipMatch != null) {
            _blockedIpToRealMac.remove(ipMatch.group(1)!);
          }
        }
      }
    } catch (e) {
      _logger.warning('Failed to rebuild state: $e');
    }
  }

  // ─── Import/Export ────────────────────────────────────────────────────────

  Future<bool> exportWhitelist(String filePath) async {
    try {
      final file = File(filePath);
      final jsonList = _whitelist.map((e) => e.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
      return true;
    } catch (e) {
      _logger.severe('Failed to export whitelist: $e');
      return false;
    }
  }

  Future<Map<String, int>> importWhitelist(String filePath) async {
    int success = 0;
    int skipped = 0;
    int failed = 0;

    try {
      final file = File(filePath);
      if (!file.existsSync()) throw Exception('Import file does not exist');
      final content = await file.readAsString();
      final decoded = jsonDecode(content);
      final List<dynamic> list = decoded is List ? decoded : [decoded];

      for (final item in list) {
        final mac = normalizeMacAddress(item['mac']?.toString() ?? '');
        final nickname = item['nickname']?.toString() ?? '';

        if (mac.isEmpty || !isValidMacAddress(mac)) {
          failed++;
          continue;
        }

        final exists = _whitelist.any((e) => e.mac == mac);
        if (exists) {
          skipped++;
          continue;
        }

        _whitelist.add(WhitelistEntry(mac: mac, nickname: nickname));
        success++;
      }

      if (success > 0) {
        await saveWhitelist();
      }

      return {
        'success': success,
        'skipped': skipped,
        'failed': failed,
      };
    } catch (e) {
      _logger.severe('Import whitelist failed: $e');
      rethrow;
    }
  }

  // ─── Windows Mobile Hotspot Control ───────────────────────────────────────

  Future<void> fetchHotspotConfig() async {
    if (!Platform.isWindows) return;
    try {
      final result = await Process.run(
          'powershell',
          [
            '-NoProfile',
            '-ExecutionPolicy',
            'Bypass',
            '-Command',
            'Add-Type -AssemblyName System.Runtime.WindowsRuntime; '
                '\$hotspotAdapter = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { \$_.InterfaceDescription -match "Wi-Fi Direct Virtual" -and \$_.Status -eq "Up" }; '
                '\$state = if (\$null -ne \$hotspotAdapter) { "Enabled" } else { "Disabled" }; '
                '\$connectionProfile = [Windows.Networking.Connectivity.NetworkInformation,Windows.Networking.Connectivity,ContentType=WindowsRuntime]::GetInternetConnectionProfile(); '
                'if (\$null -eq \$connectionProfile) { '
                '  \$profiles = [Windows.Networking.Connectivity.NetworkInformation,Windows.Networking.Connectivity,ContentType=WindowsRuntime]::GetConnectionProfiles(); '
                '  if (\$null -ne \$profiles) { '
                '    \$activeProfiles = @(\$profiles) | Where-Object { \$null -ne \$_ } | Sort-Object { [int]\$_.GetNetworkConnectivityLevel() } -Descending; '
                '    if (\$activeProfiles.Count -gt 0 -and [int]\$activeProfiles[0].GetNetworkConnectivityLevel() -gt 0) { '
                '      \$connectionProfile = \$activeProfiles[0]; '
                '    } '
                '  } '
                '}; '
                'if (\$null -ne \$connectionProfile) { '
                '  \$tetheringManager = [Windows.Networking.NetworkOperators.NetworkOperatorTetheringManager,Windows.Networking.NetworkOperators,ContentType=WindowsRuntime]::CreateFromConnectionProfile(\$connectionProfile); '
                '  if (\$null -ne \$tetheringManager) { '
                '    \$config = \$tetheringManager.GetCurrentAccessPointConfiguration(); '
                '    [PSCustomObject]@{ Ssid = \$config.Ssid; Passphrase = \$config.Passphrase; Band = \$config.Band.ToString(); State = \$state; MaxClients = \$tetheringManager.MaxClientCount; ClientCount = \$tetheringManager.ClientCount } | ConvertTo-Json; '
                '  } else { '
                '    [PSCustomObject]@{ Ssid = ""; Passphrase = ""; Band = "Auto"; State = \$state; MaxClients = 8; ClientCount = 0 } | ConvertTo-Json; '
                '  } '
                '} else { '
                '  [PSCustomObject]@{ Ssid = ""; Passphrase = ""; Band = "Auto"; State = \$state; MaxClients = 8; ClientCount = 0 } | ConvertTo-Json; '
                '}'
          ],
          runInShell: false);

      final output = result.stdout.toString().trim();
      if (output.isNotEmpty && output.startsWith('{')) {
        final Map<String, dynamic> decoded = jsonDecode(output);
        _hotspotConfig = HotspotConfig.fromJson(decoded);
      } else {
        _logger.warning(
            'Invalid PowerShell output in fetchHotspotConfig: $output');
        _hotspotConfig = HotspotConfig(
          ssid: 'Offline / No Profile',
          passphrase: '',
          band: 'Auto',
          state: 'Disabled',
          maxClients: 8,
          clientCount: 0,
        );
      }
      notifyListeners();
    } catch (e) {
      _logger.warning('Failed to fetch hotspot config: $e');
      _hotspotConfig = HotspotConfig(
        ssid: 'Error Loading',
        passphrase: '',
        band: 'Auto',
        state: 'Disabled',
        maxClients: 8,
        clientCount: 0,
      );
      notifyListeners();
    }
  }

  /// Buộc dừng quy trình ICS (SharedAccess) theo PID và khởi động lại dịch vụ.
  /// Kỹ thuật này giải quyết triệt để trường hợp dịch vụ ICS bị treo (hanging/STOP_PENDING/không thể restart thông thường).
  Future<bool> repairIcsService({bool silent = false}) async {
    if (!Platform.isWindows) return false;
    try {
      if (!silent) {
        await writeLog(
            'Đang thực hiện sửa lỗi ICS (SharedAccess): Tìm PID và buộc dừng...',
            level: 'WARN');
      }

      final script = r'''
$pidLine = sc.exe queryex SharedAccess | Select-String 'PID'
if ($pidLine) {
  $pidVal = 0
  $rawPid = $pidLine.ToString().Split(':')[-1].Trim()
  if ([int]::TryParse($rawPid, [ref]$pidVal) -and $pidVal -gt 0) {
    taskkill.exe /PID $pidVal /F | Out-Null
  }
}
Start-Sleep -Seconds 2
Start-Service -Name SharedAccess -ErrorAction SilentlyContinue
$svc = Get-Service -Name SharedAccess -ErrorAction SilentlyContinue
if ($svc) { $svc.Status.ToString() } else { 'Unknown' }
''';

      final result = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-Command',
          script,
        ],
        runInShell: false,
      );

      final status = result.stdout.toString().trim();
      final isRunning = status.toLowerCase() == 'running';

      if (!silent) {
        if (isRunning) {
          await writeLog(
              'Sửa lỗi ICS hoàn tất! Dịch vụ SharedAccess đang hoạt động (Running).',
              level: 'OK');
        } else {
          await writeLog(
              'Dịch vụ SharedAccess sau khi sửa có trạng thái: $status',
              level: 'WARN');
        }
      }

      await fetchHotspotConfig();
      return isRunning;
    } catch (e) {
      if (!silent) {
        await writeLog('Lỗi khi sửa lỗi dịch vụ ICS: $e', level: 'WARN');
      }
      _logger.warning('Failed to repair ICS service: $e');
      return false;
    }
  }

  /// Resets the Internet Connection Sharing (ICS) service to clear any DHCP leaks.
  Future<void> resetSharedAccessService() async {
    if (!Platform.isWindows) return;
    try {
      await repairIcsService(silent: true);
    } catch (e) {
      _logger.warning('Failed to reset SharedAccess service: $e');
    }
  }

  Future<bool> updateHotspotConfig(
      String ssid, String passphrase, String band, int maxClients) async {
    if (!Platform.isWindows) return false;
    const supportedBands = {
      'Auto',
      'TwoPointFourGigahertz',
      'FiveGigahertz',
      'SixGigahertz',
    };
    if (ssid.trim().isEmpty ||
        passphrase.trim().length < 8 ||
        !supportedBands.contains(band) ||
        maxClients < 1 ||
        maxClients > 128) {
      return false;
    }

    final safeSsid = _escapePowerShellSingleQuoted(ssid);
    final safePassphrase = _escapePowerShellSingleQuoted(passphrase);
    try {
      final result = await Process.run(
          'powershell',
          [
            '-NoProfile',
            '-ExecutionPolicy',
            'Bypass',
            '-Command',
            'Add-Type -AssemblyName System.Runtime.WindowsRuntime; '
                '\$asTaskAction = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { \$_.Name -eq "AsTask" -and \$_.GetParameters().Count -eq 1 -and !\$_.IsGenericMethod -and \$_.GetParameters()[0].ParameterType.Name -eq "IAsyncAction" })[0]; '
                'function AwaitAction(\$WinRtAction) { '
                '  \$netTask = \$asTaskAction.Invoke(\$null, @(\$WinRtAction)); '
                '  \$netTask.Wait(-1) | Out-Null '
                '}; '
                '\$connectionProfile = [Windows.Networking.Connectivity.NetworkInformation,Windows.Networking.Connectivity,ContentType=WindowsRuntime]::GetInternetConnectionProfile(); '
                'if (\$null -eq \$connectionProfile) { '
                '  \$profiles = [Windows.Networking.Connectivity.NetworkInformation,Windows.Networking.Connectivity,ContentType=WindowsRuntime]::GetConnectionProfiles(); '
                '  if (\$null -ne \$profiles) { '
                '    \$activeProfiles = @(\$profiles) | Where-Object { \$null -ne \$_ } | Sort-Object { [int]\$_.GetNetworkConnectivityLevel() } -Descending; '
                '    if (\$activeProfiles.Count -gt 0 -and [int]\$activeProfiles[0].GetNetworkConnectivityLevel() -gt 0) { '
                '      \$connectionProfile = \$activeProfiles[0]; '
                '    } '
                '  } '
                '}; '
                'if (\$null -ne \$connectionProfile) { '
                '  \$tetheringManager = [Windows.Networking.NetworkOperators.NetworkOperatorTetheringManager,Windows.Networking.NetworkOperators,ContentType=WindowsRuntime]::CreateFromConnectionProfile(\$connectionProfile); '
                '  if (\$null -ne \$tetheringManager) { '
                '    \$config = New-Object Windows.Networking.NetworkOperators.NetworkOperatorTetheringAccessPointConfiguration; '
                "    \$config.Ssid = '$safeSsid'; "
                "    \$config.Passphrase = '$safePassphrase'; "
                '    \$config.Band = [Windows.Networking.NetworkOperators.TetheringWiFiBand]::$band; '
                '    AwaitAction (\$tetheringManager.ConfigureAccessPointAsync(\$config)); '
                '    New-ItemProperty -Path "HKLM:\\SYSTEM\\CurrentControlSet\\Services\\icssvc\\Settings" -Name "WifiMaxPeers" -Value $maxClients -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null; '
                '    "Configured"; '
                '  } else { "NoTetheringManager"; exit 1; }'
                '} else { "NoConnectionProfile"; exit 1; }'
          ],
          runInShell: false);

      final statusLines = result.stdout
          .toString()
          .split(RegExp(r'\r?\n'))
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
      final status = statusLines.isEmpty ? null : statusLines.last;
      final succeeded = result.exitCode == 0 && status == 'Configured';
      if (!succeeded) {
        _logger.warning(
            'Hotspot configuration failed: exit=${result.exitCode}, status=$status, stderr=${result.stderr}');
        return false;
      }
      await writeLog(
          'Updated Mobile Hotspot settings: SSID=$ssid, Band=$band, MaxClients=$maxClients (Registry updated)',
          level: 'OK');
      await fetchHotspotConfig();
      return true;
    } catch (e) {
      _logger.warning('Failed to update hotspot config: $e');
      return false;
    }
  }

  Future<bool> setHotspotState(bool enable) async {
    if (!Platform.isWindows) return false;
    try {
      if (enable) {
        await writeLog(
            'Đang đặt lại dịch vụ SharedAccess (ICS) trước khi bật Hotspot...',
            level: 'INFO');
        await resetSharedAccessService();
        await Future.delayed(const Duration(seconds: 1));
      }

      final action = enable ? "StartTetheringAsync" : "StopTetheringAsync";
      final result = await Process.run(
          'powershell',
          [
            '-NoProfile',
            '-ExecutionPolicy',
            'Bypass',
            '-Command',
            'Add-Type -AssemblyName System.Runtime.WindowsRuntime; '
                '\$asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { \$_.Name -eq "AsTask" -and \$_.GetParameters().Count -eq 1 -and \$_.IsGenericMethod })[0]; '
                'function Await(\$WinRtTask, \$ResultType) { '
                '  \$asTask = \$asTaskGeneric.MakeGenericMethod(\$ResultType); '
                '  \$netTask = \$asTask.Invoke(\$null, @(\$WinRtTask)); '
                '  \$netTask.Wait(-1) | Out-Null; '
                '  \$netTask.Result '
                '}; '
                '\$connectionProfile = [Windows.Networking.Connectivity.NetworkInformation,Windows.Networking.Connectivity,ContentType=WindowsRuntime]::GetInternetConnectionProfile(); '
                'if (\$null -eq \$connectionProfile) { '
                '  \$profiles = [Windows.Networking.Connectivity.NetworkInformation,Windows.Networking.Connectivity,ContentType=WindowsRuntime]::GetConnectionProfiles(); '
                '  if (\$null -ne \$profiles) { '
                '    \$activeProfiles = @(\$profiles) | Where-Object { \$null -ne \$_ } | Sort-Object { [int]\$_.GetNetworkConnectivityLevel() } -Descending; '
                '    if (\$activeProfiles.Count -gt 0 -and [int]\$activeProfiles[0].GetNetworkConnectivityLevel() -gt 0) { '
                '      \$connectionProfile = \$activeProfiles[0]; '
                '    } '
                '  } '
                '}; '
                'if (\$null -ne \$connectionProfile) { '
                '  \$tetheringManager = [Windows.Networking.NetworkOperators.NetworkOperatorTetheringManager,Windows.Networking.NetworkOperators,ContentType=WindowsRuntime]::CreateFromConnectionProfile(\$connectionProfile); '
                '  if (\$null -ne \$tetheringManager) { '
                '    \$res = Await (\$tetheringManager.$action()) ([Windows.Networking.NetworkOperators.NetworkOperatorTetheringOperationResult]); '
                '    \$res.Status.ToString(); '
                '  } else { "NoTetheringManager"; exit 1; }'
                '} else { "NoConnectionProfile"; exit 1; }'
          ],
          runInShell: false);

      final statusLines = result.stdout
          .toString()
          .split(RegExp(r'\r?\n'))
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
      final status = statusLines.isEmpty ? null : statusLines.last;
      const successfulStatuses = {
        'Success',
        'AlreadyOn',
      };
      final succeeded = result.exitCode == 0 &&
          status != null &&
          successfulStatuses.contains(status);
      if (!succeeded) {
        _logger.warning(
            'Failed to set hotspot state: enable=$enable, exit=${result.exitCode}, status=$status, stderr=${result.stderr}');
        return false;
      }
      final stateLabel = enable ? 'Enabled' : 'Disabled';
      await writeLog('Set Mobile Hotspot state -> $stateLabel', level: 'INFO');
      await fetchHotspotConfig();
      return true;
    } catch (e) {
      _logger.warning('Failed to set hotspot state: $e');
      return false;
    }
  }

  Future<bool> fixHotspotDhcp() async {
    if (!Platform.isWindows) return false;
    try {
      await writeLog(
          'Bắt đầu quy trình tự động sửa lỗi IP/DHCP Mobile Hotspot...',
          level: 'WARN');

      // 1. Stop Hotspot first
      final stopOk = await setHotspotState(false);
      if (!stopOk) {
        await writeLog(
            'Không thể xác nhận Hotspot đã dừng; vẫn tiếp tục sửa ICS/DHCP.',
            level: 'WARN');
      }

      // 2. Restart Internet Connection Sharing (ICS) service with PID-kill
      await writeLog(
          'Đang buộc dừng và khởi động lại dịch vụ Internet Connection Sharing (ICS)...',
          level: 'INFO');
      final icsOk = await repairIcsService(silent: false);
      if (!icsOk) {
        await writeLog(
            'Không thể khởi động lại dịch vụ ICS; dừng quy trình sửa DHCP.',
            level: 'WARN');
        return false;
      }

      // 3. Reset network interface configurations (Winsock and DNS flush)
      await writeLog('Đang đặt lại Winsock và xoá bộ nhớ đệm DNS...',
          level: 'INFO');
      final networkResult = await Process.run(
          'powershell',
          [
            '-NoProfile',
            '-ExecutionPolicy',
            'Bypass',
            '-Command',
            '\$ErrorActionPreference = "Stop"; '
                'netsh winsock reset; '
                'if (\$LASTEXITCODE -ne 0) { exit \$LASTEXITCODE }; '
                'ipconfig /flushdns; '
                'exit \$LASTEXITCODE'
          ],
          runInShell: false);

      if (networkResult.exitCode != 0) {
        await writeLog(
            'Không thể reset Winsock/DNS (exit=${networkResult.exitCode}).',
            level: 'WARN');
        return false;
      }

      await writeLog(
          'Đã sửa lỗi IP/DHCP thành công! Bạn có thể bật lại Mobile Hotspot.',
          level: 'OK');
      await fetchHotspotConfig();
      return true;
    } catch (e) {
      await writeLog('Lỗi trong quá trình sửa lỗi IP/DHCP: $e', level: 'WARN');
      return false;
    }
  }
}
