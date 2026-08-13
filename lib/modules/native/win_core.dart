// lib/modules/native/win_core.dart
// Windows-specific native operations for WiFi Guard

import 'dart:io';
import 'package:logging/logging.dart';
import '../native_bridge.dart';

final _logger = Logger('WinCore');

class WindowsNativeEngine implements NativeEngine {
  WindowsNativeEngine();

  @override
  dynamic heavyCompute(dynamic dataInput) {
    return 'Windows Native Result';
  }

  /// Check if current process has admin privileges by testing 'net session' command
  static Future<bool> isAdmin() async {
    try {
      final result = await Process.run('net', ['session'], runInShell: true);
      return result.exitCode == 0;
    } catch (e) {
      _logger.warning('Failed to check admin status: $e');
      return false;
    }
  }

  /// Restart the app with admin privileges using PowerShell RunAs verb
  static Future<void> elevateAdmin() async {
    try {
      final exePath = Platform.resolvedExecutable;
      await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        'Start-Process',
        '"$exePath"',
        '-Verb',
        'RunAs',
      ]);
    } catch (e) {
      _logger.severe('Failed to elevate to admin: $e');
    }
  }
}
