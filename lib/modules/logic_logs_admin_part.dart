// lib/modules/logic_logs_admin_part.dart
// Log rotation, blocked session persistence, admin UAC, and Windows startup integration.

part of 'logic.dart';

mixin _WifiLogsAdminMixin on _WifiGuardLogicBase {
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
      final result = await _runNative(
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
        await _runNative(
            'powershell',
            [
              '-NoProfile',
              '-Command',
              'Set-ItemProperty -Path "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Run" -Name "JAWiFiGuard" -Value "\\"$exePath\\" --minimized"'
            ],
            runInShell: false);
      } else {
        await _runNative(
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

  // ─── Log Management ───────────────────────────────────────────────────────

  Future<void> _enqueueLogIo(Future<void> Function() action) {
    final next = _logIoChain.then((_) => action());
    _logIoChain = next.catchError((_) {});
    return next;
  }

  @override
  Future<void> readLogLines() async {
    await _enqueueLogIo(() async {
      try {
        final logFile = File(AppConfig.getLogPath());
        if (!await logFile.exists()) {
          _logLines = [];
          notifyListeners();
          return;
        }
        final lines = await logFile.readAsLines();
        if (lines.length > 200) {
          _logLines = lines.sublist(lines.length - 200);
        } else {
          _logLines = lines;
        }
        notifyListeners();
      } catch (e) {
        _logger.warning('Failed to read logs: $e');
      }
    });
  }

  @override
  Future<void> writeLog(String message, {String level = 'INFO'}) async {
    final timestamp = formatTimestampDisplay();
    final line = '[$timestamp][$level] $message';
    _logLines.add(line);
    if (_logLines.length > 200) {
      _logLines.removeAt(0);
    }
    notifyListeners();

    await _enqueueLogIo(() async {
      try {
        final logFile = File(AppConfig.getLogPath());
        if (!await logFile.parent.exists()) {
          await logFile.parent.create(recursive: true);
        }
        await logFile.writeAsString('$line\n',
            mode: FileMode.append, encoding: utf8);
        await _pruneLogFileIfNeeded(logFile);
      } catch (e) {
        _logger.warning('Failed to write log to file: $e');
      }
    });
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
    _logLines = [];
    notifyListeners();
    await _enqueueLogIo(() async {
      try {
        final logFile = File(AppConfig.getLogPath());
        if (await logFile.exists()) {
          await logFile.writeAsString('');
        }
      } catch (e) {
        _logger.warning('Failed to clear logs: $e');
      }
    });
  }

  @override
  Future<void> saveBlockedSession() async {
    try {
      AtomicFileStore.writeStringAtomicSync(
        AppConfig.getBlockedSessionPath(),
        jsonEncode(_blockedIpToRealMac),
        validator: AtomicFileStore.isValidJson,
      );
    } catch (e) {
      _logger.warning('Failed to save blocked session state: $e');
    }
  }

  @override
  Future<void> rebuildSessionStateFromLog() async {
    try {
      // 1. Primary recovery from persistent blocked_session.json (survives clearLogs and log pruning)
      final sessionContent = AtomicFileStore.readStringResilientSync(
        AppConfig.getBlockedSessionPath(),
        validator: AtomicFileStore.isValidJson,
      );
      if (sessionContent != null && sessionContent.trim().isNotEmpty) {
        final decoded = jsonDecode(sessionContent);
        if (decoded is Map<String, dynamic>) {
          decoded.forEach((ip, mac) {
            final normalized = normalizeMacAddress(mac?.toString() ?? '');
            if (ip.isNotEmpty && isValidMacAddress(normalized)) {
              _blockedIpToRealMac[ip] = normalized;
            }
          });
        }
      }

      // 2. Secondary supplement from wifi_guard.log if available
      final logFile = File(AppConfig.getLogPath());
      if (logFile.existsSync()) {
        final lines = logFile.readAsLinesSync();
        for (final line in lines) {
          if (line.contains('[BLOCK]')) {
            final macMatch = RegExp(r'MAC=([0-9A-Fa-f-]{17})').firstMatch(line);
            final ipMatch = RegExp(r'IP=([0-9.]+)(?:\s|$)').firstMatch(line);
            if (macMatch != null && ipMatch != null) {
              _blockedIpToRealMac[ipMatch.group(1)!] =
                  normalizeMacAddress(macMatch.group(1)!);
            }
          } else if (line.contains('UNBLOCKED')) {
            final ipMatch = RegExp(r'IP=([0-9.]+)(?:\s|$)').firstMatch(line);
            if (ipMatch != null) {
              _blockedIpToRealMac.remove(ipMatch.group(1)!);
            }
          }
        }
      }

      if (_blockedIpToRealMac.isNotEmpty) {
        await saveBlockedSession();
      }
    } catch (e) {
      _logger.warning('Failed to rebuild state: $e');
    }
  }
}
