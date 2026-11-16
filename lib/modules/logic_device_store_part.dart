// lib/modules/logic_device_store_part.dart
// Universal persistent device nicknames, whitelist management, hostname resolution, and import/export.

part of 'logic.dart';

mixin _WifiDeviceStoreMixin on _WifiGuardLogicBase {
  // ─── Universal Device Nicknames (device_names.json) ──────────────────────

  @override
  Future<void> loadDeviceNames() async {
    try {
      final path = AppConfig.getDeviceNamesPath();
      final content = AtomicFileStore.readStringResilientSync(
        path,
        validator: AtomicFileStore.isValidJson,
      );
      if (content == null || content.trim().isEmpty) {
        _customNicknames = {};
        return;
      }
      final decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic>) {
        _customNicknames = decoded.map(
          (k, v) => MapEntry(normalizeMacAddress(k), v.toString()),
        );
      }
      notifyListeners();
    } catch (e) {
      _logger.warning('Failed to load device names: $e');
      _customNicknames = {};
    }
  }

  @override
  Future<void> saveDeviceNames() async {
    try {
      AtomicFileStore.writeStringAtomicSync(
        AppConfig.getDeviceNamesPath(),
        jsonEncode(_customNicknames),
        validator: AtomicFileStore.isValidJson,
      );
    } catch (e) {
      _logger.severe('Failed to save device names: $e');
    }
  }

  // ─── Whitelist Management ─────────────────────────────────────────────────

  @override
  Future<void> loadWhitelist() async {
    try {
      final path = AppConfig.getWhitelistPath();
      final file = File(path);
      final bakFile = File('$path.bak');
      if (!file.existsSync() && !bakFile.existsSync()) {
        _whitelist = [
          WhitelistEntry(
              mac: 'D0-65-78-C4-00-9F', nickname: 'Default Allowed 1'),
          WhitelistEntry(
              mac: 'D0-65-78-D4-57-83', nickname: 'Default Allowed 2'),
        ];
        await saveWhitelist();
        return;
      }
      final content = AtomicFileStore.readStringResilientSync(
        path,
        validator: AtomicFileStore.isValidJson,
      );
      if (content == null || content.trim().isEmpty) {
        _whitelist = [];
        return;
      }
      final decoded = jsonDecode(content);
      final List<dynamic> list = decoded is List ? decoded : [decoded];
      _whitelist = list
          .map((item) {
            final mac = normalizeMacAddress(item['mac']?.toString() ?? '');
            final nick =
                _customNicknames[mac] ?? item['nickname']?.toString() ?? '';
            return WhitelistEntry(
              mac: mac,
              nickname: nick,
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

  @override
  Future<void> saveWhitelist() async {
    try {
      final jsonList = _whitelist.map((e) => e.toJson()).toList();
      AtomicFileStore.writeStringAtomicSync(
        AppConfig.getWhitelistPath(),
        jsonEncode(jsonList),
        validator: AtomicFileStore.isValidJson,
      );
      notifyListeners();
    } catch (e) {
      _logger.severe('Failed to save whitelist: $e');
    }
  }

  @override
  bool isWhitelisted(String mac) {
    final normalized = normalizeMacAddress(mac);
    return _whitelist.any((e) => e.mac == normalized);
  }

  WhitelistEntry? _getWhitelistEntry(String mac) {
    final normalized = normalizeMacAddress(mac);
    for (final entry in _whitelist) {
      if (entry.mac == normalized) return entry;
    }
    return null;
  }

  /// Get effective display nickname for a device
  @override
  String getEffectiveNickname(String mac, {String? defaultName}) {
    final normalized = normalizeMacAddress(mac);
    if (_customNicknames.containsKey(normalized) &&
        _customNicknames[normalized]!.isNotEmpty) {
      return _customNicknames[normalized]!;
    }
    final wl = _getWhitelistEntry(normalized);
    if (wl != null &&
        wl.nickname.isNotEmpty &&
        !wl.nickname.startsWith('Device_')) {
      return wl.nickname;
    }
    final bl = _getBlacklistEntry(normalized);
    if (bl != null &&
        bl.nickname.isNotEmpty &&
        !bl.nickname.startsWith('Device_')) {
      return bl.nickname;
    }
    final cached = _resolvedHostnames[normalized];
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    return defaultName ??
        (wl?.nickname ??
            bl?.nickname ??
            'Device_${normalized.replaceAll('-', '').substring(8)}');
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
      final result = await _runNative('nbtstat', ['-A', ip])
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
      final result = await _runNative(
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

  @override
  Future<void> _resolveAndSetNickname(String mac, String ip) async {
    final normalized = normalizeMacAddress(mac);
    if (_resolvingMacs.contains(normalized)) return;
    _resolvingMacs.add(normalized);

    try {
      final resolved = await _resolveHostname(ip);
      if (resolved.isNotEmpty) {
        _resolvedHostnames[normalized] = resolved;

        // If user hasn't explicitly set a custom nickname, auto-update entry in whitelist
        if (!_customNicknames.containsKey(normalized)) {
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
        }
        notifyListeners();
      }
    } finally {
      _resolvingMacs.remove(normalized);
    }
  }

  @override
  Future<bool> addWhitelistDevice(String mac, String nickname) async {
    final normalized = normalizeMacAddress(mac);
    if (!isValidMacAddress(normalized)) return false;

    // Mutual exclusion: Remove from blacklist if present
    if (isBlacklisted(normalized)) {
      _blacklist.removeWhere((e) => e.mac == normalized);
      await saveBlacklist();
      _logger.info('Removed from blacklist due to whitelisting: $normalized');
    }

    // Check if already in whitelist
    final exists = _whitelist.any((e) => e.mac == normalized);
    if (exists) return false;

    String finalNickname = nickname.trim();
    if (finalNickname.isEmpty) {
      if (_customNicknames.containsKey(normalized) &&
          _customNicknames[normalized]!.isNotEmpty) {
        finalNickname = _customNicknames[normalized]!;
      } else {
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
          finalNickname =
              'Device_${normalized.replaceAll('-', '').substring(8)}';
        }
      }
    } else {
      // Save explicitly provided nickname
      _customNicknames[normalized] = finalNickname;
      await saveDeviceNames();
    }

    _whitelist.add(WhitelistEntry(mac: normalized, nickname: finalNickname));
    await saveWhitelist();
    _logger.info('Added to whitelist: $normalized ($finalNickname)');

    // Update in-memory connected clients immediately
    _connectedClients = _connectedClients.map((c) {
      if (c.mac == normalized) {
        return ClientDevice(
          ip: c.ip,
          mac: c.mac,
          state: c.state,
          nickname: finalNickname,
          isAllowed: true,
          isWhitelisted: true,
          isBlocked: false,
          isBlacklisted: false,
        );
      }
      return c;
    }).toList();

    // Refresh connected clients if guard is active
    if (_isGuardActive) {
      await _runGuardCheck();
    } else {
      await _unblockDeviceIfBlocked(normalized);
      notifyListeners();
    }

    return true;
  }

  @override
  Future<void> removeWhitelistDevice(String mac) async {
    final normalized = normalizeMacAddress(mac);
    _whitelist.removeWhere((e) => e.mac == normalized);
    await saveWhitelist();
    _logger.info('Removed from whitelist: $normalized');

    _connectedClients = _connectedClients.map((c) {
      if (c.mac == normalized) {
        return ClientDevice(
          ip: c.ip,
          mac: c.mac,
          state: c.state,
          nickname: c.nickname,
          isAllowed: false,
          isWhitelisted: false,
          isBlocked: c.isBlacklisted,
          isBlacklisted: c.isBlacklisted,
        );
      }
      return c;
    }).toList();

    if (_isGuardActive) {
      await _runGuardCheck();
    } else {
      notifyListeners();
    }
  }

  /// Universal device rename across Whitelist, Blacklist, and Connected Clients.
  Future<void> editDeviceNickname(String mac, String newNickname) async {
    final normalized = normalizeMacAddress(mac);
    final trimmedName = newNickname.trim();
    if (trimmedName.isEmpty) return;

    // 1. Always record in custom nicknames map (persisted to device_names.json)
    _customNicknames[normalized] = trimmedName;
    await saveDeviceNames();

    // 2. Sync to whitelist if present
    bool inWhitelist = false;
    for (final entry in _whitelist) {
      if (entry.mac == normalized) {
        entry.nickname = trimmedName;
        inWhitelist = true;
        break;
      }
    }
    if (inWhitelist) {
      await saveWhitelist();
    }

    // 3. Sync to blacklist if present
    bool inBlacklist = false;
    for (final entry in _blacklist) {
      if (entry.mac == normalized) {
        entry.nickname = trimmedName;
        inBlacklist = true;
        break;
      }
    }
    if (inBlacklist) {
      await saveBlacklist();
    }

    // 4. Update in-memory connected clients immediately
    _connectedClients = _connectedClients.map((c) {
      if (c.mac == normalized) {
        return ClientDevice(
          ip: c.ip,
          mac: c.mac,
          state: c.state,
          nickname: trimmedName,
          isAllowed: c.isAllowed,
          isWhitelisted: c.isWhitelisted,
          isBlocked: c.isBlocked,
          isBlacklisted: c.isBlacklisted,
        );
      }
      return c;
    }).toList();

    notifyListeners();
    _logger.info('Updated nickname: $normalized -> $trimmedName');
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
}
