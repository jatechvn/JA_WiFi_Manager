// lib/modules/native/win_ics_service.dart
// MethodChannel client for native Win32 SCM + WinRT ICS/Hotspot repair.

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

typedef NativeIcsProgressCallback = void Function(String step);

typedef NativeIcsRepairFn = Future<Map<String, dynamic>> Function({
  Duration timeout,
  NativeIcsProgressCallback? onProgressStep,
});

/// Native C++ channel client executing bounded Win32 SCM and WinRT ABI calls
/// without spawning external PowerShell processes.
class WinIcsNativeService {
  static const String channelName = 'ja_wifi_manager/ics_repair';
  static const MethodChannel _channel = MethodChannel(channelName);

  static Map<String, dynamic> _normalizeMap(Object? raw) {
    if (raw is! Map) {
      return const <String, dynamic>{};
    }
    final normalized = <String, dynamic>{};
    raw.forEach((key, value) {
      if (key == null) return;
      final stringKey = key.toString();
      if (value is Map) {
        normalized[stringKey] = _normalizeMap(value);
      } else {
        normalized[stringKey] = value;
      }
    });
    return normalized;
  }

  /// Invokes native `repairIcs` in the Windows runner with live step progress.
  static Future<Map<String, dynamic>> repairIcs({
    Duration timeout = const Duration(seconds: 60),
    NativeIcsProgressCallback? onProgressStep,
  }) async {
    if (!Platform.isWindows) {
      return const <String, dynamic>{
        'Ok': false,
        'ServicesRecovered': false,
        'HotspotState': 'Unknown',
        'Step': 'Platform check',
        'Error': 'Native ICS repair is only supported on Windows',
      };
    }

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onProgress') {
        final step = call.arguments?.toString().trim() ?? '';
        if (step.isNotEmpty) {
          onProgressStep?.call(step);
        }
      }
    });

    try {
      final raw = await _channel.invokeMethod<Object?>(
        'repairIcs',
        const <String, int>{
          'stopTimeoutMs': 12000,
          'startTimeoutMs': 15000,
          'stableTimeoutMs': 8000,
        },
      ).timeout(timeout);

      final parsed = _normalizeMap(raw);
      if (parsed.isEmpty) {
        return const <String, dynamic>{
          'Ok': false,
          'ServicesRecovered': false,
          'HotspotState': 'Unknown',
          'Step': 'Read repair result',
          'Error': 'Empty response from native ICS channel',
        };
      }
      return parsed;
    } on TimeoutException {
      return <String, dynamic>{
        'Ok': false,
        'ServicesRecovered': false,
        'HotspotState': 'Unknown',
        'Step': 'Native ICS channel',
        'Error':
            'Timed out after ${timeout.inSeconds}s waiting for native ICS repair',
      };
    } on MissingPluginException {
      return const <String, dynamic>{
        'Ok': false,
        'ServicesRecovered': false,
        'HotspotState': 'Unknown',
        'Step': 'Native ICS channel',
        'Error': 'Native ICS repair channel is unavailable',
      };
    } on PlatformException catch (e) {
      return <String, dynamic>{
        'Ok': false,
        'ServicesRecovered': false,
        'HotspotState': 'Unknown',
        'Step': 'Native ICS channel',
        'Error': e.message ?? e.code,
      };
    } finally {
      _channel.setMethodCallHandler(null);
    }
  }
}
