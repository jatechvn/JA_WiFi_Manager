// lib/modules/logic_guard_engine_part.dart
// Guard monitoring loop with re-entrancy coalescing and idempotent ARP + Firewall enforcement.

part of 'logic.dart';

mixin _WifiGuardEngineMixin on _WifiGuardLogicBase {
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
    _pendingGuardCheck = false;
    _guardLoopTimer?.cancel();
    _guardLoopTimer = null;

    _statusMessage = 'Stopping Guard...';
    notifyListeners();

    try {
      await writeLog('====== WiFi Guard stopped and cleaned ======',
          level: 'WARN');
      final transientMacs = _blockedIpToRealMac.values
          .where((mac) => !isBlacklisted(mac))
          .toSet();
      for (final mac in transientMacs) {
        await _unblockDeviceIfBlocked(mac);
      }
      await scanConnectedClients();
      _statusMessage = 'Guard is inactive.';
      notifyListeners();
    } catch (e) {
      _logger.severe('Error stopping Guard: $e');
      _statusMessage = 'Error stopping: $e';
      notifyListeners();
    }
  }

  @override
  Future<void> _runGuardCheck() async {
    if (!Platform.isWindows) return;
    if (_isGuardCheckInProgress) {
      _pendingGuardCheck = true;
      await _activeGuardCheckCompleter?.future;
      return;
    }

    _isGuardCheckInProgress = true;
    final completer = Completer<void>();
    _activeGuardCheckCompleter = completer;

    try {
      do {
        _pendingGuardCheck = false;
        if (!_isGuardActive) break;
        await _performSingleGuardCheckPass();
      } while (_pendingGuardCheck && _isGuardActive);
    } finally {
      _isGuardCheckInProgress = false;
      _pendingGuardCheck = false;
      _activeGuardCheckCompleter = null;
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
  }

  Future<void> _reEnforceArpPoison(int? ifIndex, String ip) async {
    await _runNative(
        'powershell',
        [
          '-NoProfile',
          '-Command',
          'Remove-NetNeighbor -InterfaceIndex $ifIndex -IPAddress $ip -Confirm:\$false -ErrorAction SilentlyContinue; New-NetNeighbor -InterfaceIndex $ifIndex -IPAddress $ip -LinkLayerAddress "00-00-00-00-00-01" -State Permanent -ErrorAction SilentlyContinue'
        ],
        runInShell: false);
  }

  Future<void> _applyDualLayerBlock({
    required int? ifIndex,
    required String adapterName,
    required String ip,
    required String realMac,
  }) async {
    final ruleTag = ip.replaceAll('.', '-');
    await _runNative(
        'powershell',
        [
          '-NoProfile',
          '-Command',
          'Remove-NetNeighbor -InterfaceIndex $ifIndex -IPAddress $ip -Confirm:\$false -ErrorAction SilentlyContinue; '
              'New-NetNeighbor -InterfaceIndex $ifIndex -IPAddress $ip -LinkLayerAddress "00-00-00-00-00-01" -State Permanent -ErrorAction SilentlyContinue; '
              'Remove-NetFirewallRule -DisplayName "WiFiGuard_${ruleTag}_IN" -ErrorAction SilentlyContinue; '
              'New-NetFirewallRule -DisplayName "WiFiGuard_${ruleTag}_IN" -Description "MAC=$realMac" -Direction Inbound -Action Block -RemoteAddress $ip -InterfaceAlias "$adapterName" -Protocol Any -Enabled True -ErrorAction SilentlyContinue'
        ],
        runInShell: false);
    _blockedIpToRealMac[ip] = realMac;
  }

  Future<void> _performSingleGuardCheckPass() async {
    if (_hotspotOperationInProgress) return;
    try {
      // Combined command: Get IP, index, adapter name, and neighbors in one single PowerShell call
      final combinedResult = await _runNative(
          'powershell',
          [
            '-NoProfile',
            '-ExecutionPolicy',
            'Bypass',
            '-Command',
            '\$ipEntry = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { \$_.IPAddress -like "192.168.137.*" } | Select-Object -First 1; if (\$ipEntry) { \$ifIndex = \$ipEntry.InterfaceIndex; \$adapterName = (Get-NetAdapter -InterfaceIndex \$ifIndex | Select-Object -ExpandProperty Name -First 1); \$neighbors = @(Get-NetNeighbor -InterfaceIndex \$ifIndex -ErrorAction SilentlyContinue | Where-Object { \$_.State -in @("Reachable", "Stale", "Permanent") -and \$_.LinkLayerAddress -notmatch "^(FF-FF-FF-FF-FF-FF|01-00-5E|33-33|00-00-00-00-00)" -and \$_.IPAddress -notmatch "^(224\\.|239\\.|255\\.)" } | Select-Object IPAddress, LinkLayerAddress, State); [PSCustomObject]@{ InterfaceIndex = \$ifIndex; AdapterName = \$adapterName; Neighbors = \$neighbors } | ConvertTo-Json -Depth 4 }'
          ],
          runInShell: false);

      if (!_isGuardActive) return;

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
      final blMacs = _blacklist.map((e) => e.mac.toUpperCase()).toSet();
      final List<ClientDevice> currentClientsList = [];
      bool blockedMapChanged = false;

      for (final item in jsonList) {
        if (!_isGuardActive) return;

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

        final isBlacklistedDevice = blMacs.contains(realMac);
        final isWhitelistedDevice =
            !isBlacklistedDevice && wlMacs.contains(realMac);

        if (isBlacklistedDevice) {
          if (_blockedIpToRealMac.containsKey(ip) || isPoisoned) {
            await _reEnforceArpPoison(ifIndex, ip);
          } else {
            await writeLog('BLACKLISTED: MAC=$realMac  IP=$ip --> Blocking...',
                level: 'WARN');
            await _applyDualLayerBlock(
              ifIndex: ifIndex,
              adapterName: adapterName,
              ip: ip,
              realMac: realMac,
            );
            blockedMapChanged = true;
            await writeLog(
                'BLOCKED: MAC=$realMac  IP=$ip  [Blacklist - ARP Poison + Firewall IN]',
                level: 'BLOCK');
          }
        } else if (isWhitelistedDevice) {
          if (isPoisoned || _blockedIpToRealMac.containsKey(ip)) {
            final ruleTag = ip.replaceAll('.', '-');
            await _runNative(
                'powershell',
                [
                  '-NoProfile',
                  '-Command',
                  'Remove-NetNeighbor -InterfaceIndex $ifIndex -IPAddress $ip -Confirm:\$false -ErrorAction SilentlyContinue; '
                      'Remove-NetFirewallRule -DisplayName "WiFiGuard_${ruleTag}_IN" -ErrorAction SilentlyContinue'
                ],
                runInShell: false);

            _blockedIpToRealMac.remove(ip);
            blockedMapChanged = true;
            isPoisoned = false;
            await writeLog('UNBLOCKED: MAC=$realMac  IP=$ip', level: 'OK');
          } else {
            await writeLog('ALLOWED : MAC=$realMac  IP=$ip', level: 'ALLOW');
          }
        } else {
          if (_blockedIpToRealMac.containsKey(ip) || isPoisoned) {
            await _reEnforceArpPoison(ifIndex, ip);
          } else {
            await writeLog('INTRUDER: MAC=$realMac  IP=$ip --> Blocking...',
                level: 'WARN');
            await _applyDualLayerBlock(
              ifIndex: ifIndex,
              adapterName: adapterName,
              ip: ip,
              realMac: realMac,
            );
            blockedMapChanged = true;
            await writeLog(
                'BLOCKED: MAC=$realMac  IP=$ip  [ARP Poison + Firewall IN]',
                level: 'BLOCK');
          }
        }

        final cachedHostname = _resolvedHostnames[realMac] ?? '';
        if (cachedHostname.isEmpty) {
          _resolveAndSetNickname(realMac, ip);
        }

        final displayName =
            getEffectiveNickname(realMac, defaultName: cachedHostname);

        currentClientsList.add(ClientDevice(
          ip: ip,
          mac: realMac,
          state: _mapNeighborStateLabel(stateCode),
          nickname: displayName,
          isAllowed: isWhitelistedDevice,
          isWhitelisted: isWhitelistedDevice,
          isBlocked: isPoisoned ||
              _blockedIpToRealMac.containsKey(ip) ||
              isBlacklistedDevice,
          isBlacklisted: isBlacklistedDevice,
        ));
      }

      if (blockedMapChanged) {
        await saveBlockedSession();
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
}
