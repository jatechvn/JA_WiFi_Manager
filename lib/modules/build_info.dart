// lib/modules/build_info.dart
// Diagnostic build info and AOT compile timestamp reader

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'constants.dart';

class BuildInfo {
  static bool isCliDebug = false;
  static final String debugTimestamp = _generateBuildTimestamp();

  static String _generateBuildTimestamp() {
    try {
      final exeFile = File(Platform.resolvedExecutable);
      final appSoFile = File(
          '${exeFile.parent.path}${Platform.pathSeparator}data${Platform.pathSeparator}app.so');
      final targetFile = appSoFile.existsSync() ? appSoFile : exeFile;

      if (targetFile.existsSync()) {
        final modified = targetFile.lastModifiedSync();
        String pad(int n) => n.toString().padLeft(2, '0');
        return '${modified.year}-${pad(modified.month)}-${pad(modified.day)} '
            '${pad(modified.hour)}:${pad(modified.minute)}:${pad(modified.second)}';
      }
    } catch (_) {}
    return DateTime.now().toString().split('.')[0];
  }

  static bool get isDebug => kDebugMode || isCliDebug;
  static const String version = appVersion;
}
