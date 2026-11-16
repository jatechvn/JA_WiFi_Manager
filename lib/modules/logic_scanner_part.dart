// lib/modules/logic_scanner_part.dart
// Single-pass ARP neighbor scanner and MAC deduplication for Monitor and Blacklist sync.

part of 'logic.dart';

mixin _WifiScannerMixin on _WifiGuardLogicBase {
  // ─── Connected Clients Scanner (Single pass query for Manual Refresh) ─────

  @override
  Future<void> scanConnectedClients() async {
    if (!Platform.isWindows) return;
    if (_hotspotOperationInProgress) return;
    if (_isScanInProgress) {
      await _activeScanCompleter?.future;
      return;
    }

    _isScanInProgress = true;
    final completer = Completer<void>();
    _activeScanCompleter = completer;

    try {
      final combinedResult = await _runNative(
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

        final isBlacklistedDevice = isBlacklisted(realMac);
        final isWhitelistedDevice =
            !isBlacklistedDevice && isWhitelisted(realMac);

        final cachedHostname = _resolvedHostnames[realMac] ?? '';
        if (cachedHostname.isEmpty) {
          _resolveAndSetNickname(realMac, ip);
        }

        final displayName =
            getEffectiveNickname(realMac, defaultName: cachedHostname);
        final isAllowed =
            isWhitelistedDevice && !isPoisoned && !isBlacklistedDevice;

        list.add(ClientDevice(
          ip: ip,
          mac: realMac,
          state: _mapNeighborStateLabel(stateCode),
          nickname: displayName,
          isAllowed: isAllowed,
          isWhitelisted: isWhitelistedDevice,
          isBlocked: isPoisoned || _blockedIpToRealMac.containsKey(ip),
          isBlacklisted: isBlacklistedDevice,
        ));
      }

      _connectedClients = _dedupeByMac(list);
      for (final client in List<ClientDevice>.from(_connectedClients)) {
        if (client.isBlacklisted) await _enforceBlacklistBlock(client.mac);
      }
      notifyListeners();
    } catch (e) {
      _logger.warning('Scan connected clients failed: $e');
    } finally {
      _isScanInProgress = false;
      _activeScanCompleter = null;
      if (!completer.isCompleted) {
        completer.complete();
      }
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

  // Collapse multi-row Windows Get-NetNeighbor entries per device into one canonical row
  // (IPv4 preferred over IPv6; Reachable preferred over Stale/Permanent/Delay/Probe).
  @override
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
}
