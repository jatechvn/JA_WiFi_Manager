// lib/modules/utils/atomic_file_store.dart
// Atomic file persistence with .tmp staging and .bak automatic recovery

import 'dart:convert';
import 'dart:io';
import 'package:logging/logging.dart';

final _logger = Logger('AtomicFileStore');

class AtomicFileStore {
  const AtomicFileStore._();

  /// Validator that checks if a string is non-empty valid JSON.
  static bool isValidJson(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return false;
    try {
      jsonDecode(trimmed);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Validator that checks if an INI configuration string is non-empty and contains key=value or section header.
  static bool isValidIni(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return false;
    return trimmed.contains('=') || trimmed.startsWith('[');
  }

  /// Synchronously writes [content] to [filePath] atomically via `.tmp` and maintains a `.bak` copy.
  static void writeStringAtomicSync(
    String filePath,
    String content, {
    bool Function(String)? validator,
    bool createParentDirs = true,
  }) {
    final targetFile = File(filePath);
    final parent = targetFile.parent;
    if (createParentDirs && !parent.existsSync()) {
      parent.createSync(recursive: true);
    }

    final tmpFile = File('$filePath.tmp');
    final bakFile = File('$filePath.bak');

    // 1. Write new content to .tmp and flush to disk
    tmpFile.writeAsStringSync(content, flush: true);

    // 2. If current target file exists and is valid, back it up to .bak
    if (targetFile.existsSync()) {
      try {
        final currentContent = targetFile.readAsStringSync();
        final isCurrentValid = validator != null
            ? validator(currentContent)
            : currentContent.trim().isNotEmpty;
        if (isCurrentValid) {
          targetFile.copySync(bakFile.path);
        }
      } catch (e) {
        _logger.warning('Could not backup existing file $filePath: $e');
      }
    }

    // 3. Atomically replace target file with .tmp
    try {
      tmpFile.renameSync(filePath);
    } catch (_) {
      // Fallback for Windows when rename across locked handles transiently fails
      tmpFile.copySync(filePath);
      try {
        tmpFile.deleteSync();
      } catch (_) {}
    }

    // 4. Ensure a valid .bak exists for first-time writes
    if (!bakFile.existsSync()) {
      try {
        targetFile.copySync(bakFile.path);
      } catch (_) {}
    }
  }

  /// Asynchronously writes [content] to [filePath] atomically via `.tmp` and maintains a `.bak` copy.
  static Future<void> writeStringAtomic(
    String filePath,
    String content, {
    bool Function(String)? validator,
    bool createParentDirs = true,
  }) async {
    writeStringAtomicSync(
      filePath,
      content,
      validator: validator,
      createParentDirs: createParentDirs,
    );
  }

  /// Synchronously reads [filePath], automatically falling back to and restoring from `$filePath.bak`
  /// if the primary file is missing, empty, or fails [validator].
  static String? readStringResilientSync(
    String filePath, {
    bool Function(String)? validator,
  }) {
    final targetFile = File(filePath);
    final bakFile = File('$filePath.bak');

    bool checkValid(String text) {
      if (validator != null) return validator(text);
      return text.trim().isNotEmpty;
    }

    if (targetFile.existsSync()) {
      try {
        final content = targetFile.readAsStringSync();
        if (checkValid(content)) {
          return content;
        }
        _logger.warning(
          'Primary file $filePath is corrupted or empty; attempting recovery from .bak',
        );
      } catch (e) {
        _logger.warning(
          'Failed to read primary file $filePath ($e); attempting recovery from .bak',
        );
      }
    }

    if (bakFile.existsSync()) {
      try {
        final bakContent = bakFile.readAsStringSync();
        if (checkValid(bakContent)) {
          try {
            bakFile.copySync(filePath);
            _logger.info('Successfully restored $filePath from .bak backup.');
          } catch (e) {
            _logger.warning('Could not overwrite $filePath from .bak: $e');
          }
          return bakContent;
        }
      } catch (e) {
        _logger.warning('Failed to read backup file ${bakFile.path}: $e');
      }
    }

    return null;
  }

  /// Asynchronously reads [filePath] with `.bak` fallback recovery.
  static Future<String?> readStringResilient(
    String filePath, {
    bool Function(String)? validator,
  }) async {
    return readStringResilientSync(filePath, validator: validator);
  }
}
