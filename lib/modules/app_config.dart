// lib/modules/app_config.dart
// Simple INI-style config file reader/writer
// Stores config.ini next to the executable in release, or in the workspace root in debug

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class AppConfig {
  static String? _configPath;
  static Map<String, String> _values = {};
  static bool enableTransparency = true;

  /// Initialize and load config from disk.
  /// Creates config.ini with defaults if it doesn't exist.
  static Future<void> initialize() async {
    try {
      if (kDebugMode) {
        _configPath = p.join(Directory.current.path, 'config.ini');
      } else {
        final exeDir = p.dirname(Platform.resolvedExecutable);
        _configPath = p.join(exeDir, 'config.ini');
      }
      await _load();
    } catch (_) {
      _configPath = 'config.ini';
      await _load();
    }

    enableTransparency = Platform.isWindows;
    if (_values.containsKey('enable_transparency')) {
      _values.remove('enable_transparency');
      await _save();
    }
  }

  static bool isWindows11OrNewer() {
    if (!Platform.isWindows) return false;
    try {
      final versionStr = Platform.operatingSystemVersion;
      final match = RegExp(r'Build\s+(\d+)').firstMatch(versionStr);
      if (match != null) {
        final buildNumber = int.tryParse(match.group(1) ?? '') ?? 0;
        return buildNumber >= 22000;
      }
    } catch (_) {}
    return false;
  }

  static Future<void> _load() async {
    try {
      final file = File(_configPath!);
      if (!file.existsSync()) {
        _values = {'language': 'en', 'theme': 'dark'};
        await _save();
        return;
      }

      _values = {};
      final lines = file.readAsLinesSync();
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty ||
            trimmed.startsWith('#') ||
            trimmed.startsWith('[')) {
          continue;
        }
        final eqIdx = trimmed.indexOf('=');
        if (eqIdx > 0) {
          final key = trimmed.substring(0, eqIdx).trim();
          final value = trimmed.substring(eqIdx + 1).trim();
          _values[key] = value;
        }
      }
    } catch (_) {
      _values = {'language': 'en', 'theme': 'dark'};
    }
  }

  static Future<void> _save() async {
    try {
      if (_configPath == null) return;
      final file = File(_configPath!);
      final parent = file.parent;
      if (!parent.existsSync()) {
        parent.createSync(recursive: true);
      }
      final buffer = StringBuffer();
      buffer.writeln('[app]');
      _values.forEach((k, v) => buffer.writeln('$k=$v'));
      file.writeAsStringSync(buffer.toString());
    } catch (_) {}
  }

  /// Get a config value by key, with optional default.
  static String get(String key, {String defaultValue = ''}) {
    return _values[key] ?? defaultValue;
  }

  /// Set a config value and immediately persist to disk.
  static Future<void> set(String key, String value) async {
    _values[key] = value;
    await _save();
  }

  /// Path to the whitelisted devices json
  static String getWhitelistPath() {
    if (_configPath != null) {
      return p.join(p.dirname(_configPath!), 'whitelist.json');
    }
    return 'whitelist.json';
  }

  /// Path to extract/run the powershell script
  static String getScriptPath() {
    if (_configPath != null) {
      return p.join(p.dirname(_configPath!), 'wifi_whitelist.ps1');
    }
    return 'wifi_whitelist.ps1';
  }

  /// Path to the guard log file
  static String getLogPath() {
    if (_configPath != null) {
      return p.join(p.dirname(_configPath!), 'wifi_guard.log');
    }
    return 'wifi_guard.log';
  }
}
