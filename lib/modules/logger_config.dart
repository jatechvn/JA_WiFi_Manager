// lib/modules/logger_config.dart
// Centralized logger configuration

import 'dart:io';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

IOSink? _logFileSink;

void setupLogger() {
  Logger.root.level = Level.ALL;

  // Create logs directory relative to executable in release mode
  final baseDir = Platform.resolvedExecutable.contains('dart')
      ? Directory.current.path
      : p.dirname(Platform.resolvedExecutable);
  final logDir = Directory(p.join(baseDir, 'logs'));
  if (!logDir.existsSync()) {
    logDir.createSync(recursive: true);
  }

  // Prune daily logs older than 7 days
  try {
    final now = DateTime.now();
    final limit = now.subtract(const Duration(days: 7));
    if (logDir.existsSync()) {
      for (final file in logDir.listSync().whereType<File>()) {
        final stat = file.statSync();
        if (stat.modified.isBefore(limit)) {
          file.deleteSync();
        }
      }
    }
  } catch (_) {}

  // Daily log file
  final now = DateTime.now();
  final logFileName =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}.log';
  final logFile = File(p.join(logDir.path, logFileName));
  _logFileSink = logFile.openWrite(mode: FileMode.append);

  Logger.root.onRecord.listen((record) {
    final message =
        '[${record.time}] ${record.level.name}: ${record.loggerName} - ${record.message}';
    // Console output
    // ignore: avoid_print
    print(message);
    // File output
    _logFileSink?.writeln(message);
  });
}

void disposeLogger() {
  _logFileSink?.close();
}
