// lib/modules/logic_blacklist_part.dart
// Blacklist persistence, mutual-exclusion transfers, and immediate dual-layer blocking.

part of 'logic.dart';

mixin _WifiBlacklistMixin on _WifiGuardLogicBase {
  // ─── Blacklist Management (blacklist.json) ────────────────────────────────

  @override
  Future<void> loadBlacklist() async {
    try {
      final path = AppConfig.getBlacklistPath();
      final content = AtomicFileStore.readStringResilientSync(
        path,
        validator: AtomicFileStore.isValidJson,
      );
      if (content == null || content.trim().isEmpty) {
        _blacklist = [];
        return;
      }
      final decoded = jsonDecode(content);
      final List<dynamic> list = decoded is List ? decoded : [decoded];
      _blacklist = list
          .map((item) {
            final entry = BlacklistEntry.fromJson(item as Map<String, dynamic>);
            if (_customNicknames.containsKey(entry.mac) &&
                _customNicknames[entry.mac]!.isNotEmpty) {
              entry.nickname = _customNicknames[entry.mac]!;
            }
            return entry;
          })
          .where((e) => e.mac.isNotEmpty)
          .toList();
      notifyListeners();
    } catch (e) {
      _logger.warning('Failed to load blacklist: $e');
      _blacklist = [];
    }
  }

  @override
  Future<void> saveBlacklist() async {
    try {
      final jsonList = _blacklist.map((e) => e.toJson()).toList();
      AtomicFileStore.writeStringAtomicSync(
        AppConfig.getBlacklistPath(),
        jsonEncode(jsonList),
        validator: AtomicFileStore.isValidJson,
      );
      notifyListeners();
    } catch (e) {
      _logger.severe('Failed to save blacklist: $e');
    }
  }

  @override
  bool isBlacklisted(String mac) {
    final normalized = normalizeMacAddress(mac);
    return _blacklist.any((e) => e.mac == normalized);
  }

  @override
  BlacklistEntry? _getBlacklistEntry(String mac) {
    final normalized = normalizeMacAddress(mac);
    for (final entry in _blacklist) {
      if (entry.mac == normalized) return entry;
    }
    return null;
  }

  @override
  Future<bool> addBlacklistDevice(String mac, String nickname,
      {String reason = ''}) async {
    final normalized = normalizeMacAddress(mac);
    if (!isValidMacAddress(normalized)) return false;

    // Mutual exclusion: Remove from whitelist if present
    if (isWhitelisted(normalized)) {
      _whitelist.removeWhere((e) => e.mac == normalized);
      await saveWhitelist();
      _logger.info('Removed from whitelist due to blacklisting: $normalized');
    }

    // Check if already in blacklist
    final exists = _blacklist.any((e) => e.mac == normalized);
    if (exists) {
      if (reason.isNotEmpty || nickname.isNotEmpty) {
        for (final entry in _blacklist) {
          if (entry.mac == normalized) {
            if (reason.isNotEmpty) entry.reason = reason;
            if (nickname.isNotEmpty) {
              entry.nickname = nickname.trim();
              _customNicknames[normalized] = nickname.trim();
              await saveDeviceNames();
            }
            break;
          }
        }
        await saveBlacklist();
      }
      return false;
    }

    String finalNickname = nickname.trim();
    if (finalNickname.isEmpty) {
      finalNickname = getEffectiveNickname(normalized);
    } else {
      _customNicknames[normalized] = finalNickname;
      await saveDeviceNames();
    }

    _blacklist.add(BlacklistEntry(
      mac: normalized,
      nickname: finalNickname,
      addedAt: DateTime.now(),
      reason: reason.trim(),
    ));
    await saveBlacklist();
    _logger.info('Added to blacklist: $normalized ($finalNickname)');

    // Update in-memory connected clients immediately
    _connectedClients = _connectedClients.map((c) {
      if (c.mac == normalized) {
        return ClientDevice(
          ip: c.ip,
          mac: c.mac,
          state: c.state,
          nickname: finalNickname,
          isAllowed: false,
          isWhitelisted: false,
          isBlocked: true,
          isBlacklisted: true,
        );
      }
      return c;
    }).toList();
    notifyListeners();

    // Immediately enforce block if device is connected
    await _enforceBlacklistBlock(normalized);

    return true;
  }

  @override
  Future<void> removeBlacklistDevice(String mac) async {
    final normalized = normalizeMacAddress(mac);
    _blacklist.removeWhere((e) => e.mac == normalized);
    await saveBlacklist();
    _logger.info('Removed from blacklist: $normalized');

    _connectedClients = _connectedClients.map((c) {
      if (c.mac == normalized) {
        final whitelisted = isWhitelisted(normalized);
        return ClientDevice(
          ip: c.ip,
          mac: c.mac,
          state: c.state,
          nickname: c.nickname,
          isAllowed: whitelisted,
          isWhitelisted: whitelisted,
          isBlocked: false,
          isBlacklisted: false,
        );
      }
      return c;
    }).toList();

    if (_isGuardActive) {
      await _runGuardCheck();
    } else {
      await _unblockDeviceIfBlocked(normalized);
      notifyListeners();
    }
  }

  Future<bool> moveToWhitelist(String mac) async {
    final normalized = normalizeMacAddress(mac);
    BlacklistEntry? entry;
    for (final e in _blacklist) {
      if (e.mac == normalized) {
        entry = e;
        break;
      }
    }
    final name = entry?.nickname ?? getEffectiveNickname(normalized);
    await removeBlacklistDevice(normalized);
    return await addWhitelistDevice(normalized, name);
  }

  Future<bool> moveToBlacklist(String mac, {String reason = ''}) async {
    final normalized = normalizeMacAddress(mac);
    WhitelistEntry? entry;
    for (final e in _whitelist) {
      if (e.mac == normalized) {
        entry = e;
        break;
      }
    }
    final name = entry?.nickname ?? getEffectiveNickname(normalized);
    await removeWhitelistDevice(normalized);
    return await addBlacklistDevice(normalized, name, reason: reason);
  }

  @override
  Future<void> _enforceBlacklistBlock(String mac) async {
    if (!Platform.isWindows) return;
    final normalized = normalizeMacAddress(mac);

    ClientDevice? connected;
    for (final c in _connectedClients) {
      if (c.mac == normalized) {
        connected = c;
        break;
      }
    }

    if (connected != null && connected.ip.isNotEmpty) {
      final ip = connected.ip;
      await writeLog(
          'BLACKLIST: MAC=$normalized  IP=$ip --> Blocking immediately...',
          level: 'WARN');

      try {
        final combinedResult = await _runNative(
            'powershell',
            [
              '-NoProfile',
              '-ExecutionPolicy',
              'Bypass',
              '-Command',
              '\$ipEntry = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { \$_.IPAddress -like "192.168.137.*" } | Select-Object -First 1; if (\$ipEntry) { \$ifIndex = \$ipEntry.InterfaceIndex; \$adapterName = (Get-NetAdapter -InterfaceIndex \$ifIndex | Select-Object -ExpandProperty Name -First 1); [PSCustomObject]@{ InterfaceIndex = \$ifIndex; AdapterName = \$adapterName } | ConvertTo-Json }'
            ],
            runInShell: false);

        final out = combinedResult.stdout.toString().trim();
        if (out.isNotEmpty && out.startsWith('{')) {
          final decoded = jsonDecode(out);
          final ifIndex = decoded['InterfaceIndex'] as int?;
          final adapterName = decoded['AdapterName']?.toString() ?? '';

          if (ifIndex != null) {
            final ruleTag = ip.replaceAll('.', '-');
            await _runNative(
                'powershell',
                [
                  '-NoProfile',
                  '-Command',
                  'Remove-NetNeighbor -InterfaceIndex $ifIndex -IPAddress $ip -Confirm:\$false -ErrorAction SilentlyContinue; '
                      'New-NetNeighbor -InterfaceIndex $ifIndex -IPAddress $ip -LinkLayerAddress "00-00-00-00-00-01" -State Permanent -ErrorAction SilentlyContinue; '
                      'Remove-NetFirewallRule -DisplayName "WiFiGuard_${ruleTag}_IN" -ErrorAction SilentlyContinue; '
                      'New-NetFirewallRule -DisplayName "WiFiGuard_${ruleTag}_IN" -Description "MAC=$normalized" -Direction Inbound -Action Block -RemoteAddress $ip -InterfaceAlias "$adapterName" -Protocol Any -Enabled True -ErrorAction SilentlyContinue'
                ],
                runInShell: false);

            _blockedIpToRealMac[ip] = normalized;
            await saveBlockedSession();
            _connectedClients = _connectedClients
                .map((client) => client.mac == normalized
                    ? ClientDevice(
                        ip: client.ip,
                        mac: client.mac,
                        state: client.state,
                        nickname: client.nickname,
                        isAllowed: false,
                        isWhitelisted: false,
                        isBlocked: true,
                        isBlacklisted: true,
                      )
                    : client)
                .toList();
            await writeLog(
                'BLOCKED BLACKLISTED: MAC=$normalized  IP=$ip  [ARP Poison + Firewall IN]',
                level: 'BLOCK');
          }
        }
      } catch (e) {
        _logger.warning('Failed to block blacklisted device $normalized: $e');
      }
    }

    if (_isGuardActive) {
      await _runGuardCheck();
    } else {
      notifyListeners();
    }
  }

  @override
  Future<void> _unblockDeviceIfBlocked(String mac) async {
    if (!Platform.isWindows) return;
    final normalized = normalizeMacAddress(mac);

    String? targetIp;
    _blockedIpToRealMac.forEach((ip, m) {
      if (m == normalized) targetIp = ip;
    });

    if (targetIp == null) {
      for (final c in _connectedClients) {
        if (c.mac == normalized && c.isBlocked) {
          targetIp = c.ip;
          break;
        }
      }
    }

    if (targetIp != null && targetIp!.isNotEmpty) {
      try {
        final combinedResult = await _runNative(
            'powershell',
            [
              '-NoProfile',
              '-ExecutionPolicy',
              'Bypass',
              '-Command',
              '\$ipEntry = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { \$_.IPAddress -like "192.168.137.*" } | Select-Object -First 1; if (\$ipEntry) { \$ipEntry.InterfaceIndex }'
            ],
            runInShell: false);
        final ifIndexStr = combinedResult.stdout.toString().trim();
        final ifIndex = int.tryParse(ifIndexStr);

        if (ifIndex != null) {
          final ruleTag = targetIp!.replaceAll('.', '-');
          await _runNative(
              'powershell',
              [
                '-NoProfile',
                '-Command',
                'Remove-NetNeighbor -InterfaceIndex $ifIndex -IPAddress $targetIp -Confirm:\$false -ErrorAction SilentlyContinue; '
                    'Remove-NetFirewallRule -DisplayName "WiFiGuard_${ruleTag}_IN" -ErrorAction SilentlyContinue'
              ],
              runInShell: false);

          _blockedIpToRealMac.remove(targetIp);
          await saveBlockedSession();
          await writeLog('UNBLOCKED: MAC=$normalized  IP=$targetIp',
              level: 'OK');
        }
      } catch (e) {
        _logger.warning('Failed to unblock device $normalized: $e');
      }
    }
  }
}
