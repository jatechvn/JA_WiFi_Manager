// lib/modules/utils.dart
// Shared utility helper functions for WiFi Guard

/// Format timestamp: yyyy-MM-dd_HH:mm:ss
String formatTimestamp([DateTime? dt]) {
  final now = dt ?? DateTime.now();
  return '${now.year}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}_'
      '${now.hour.toString().padLeft(2, '0')}:'
      '${now.minute.toString().padLeft(2, '0')}:'
      '${now.second.toString().padLeft(2, '0')}';
}

/// Format timestamp for display: yyyy-MM-dd HH:mm:ss
String formatTimestampDisplay([DateTime? dt]) {
  final now = dt ?? DateTime.now();
  return '${now.year}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')} '
      '${now.hour.toString().padLeft(2, '0')}:'
      '${now.minute.toString().padLeft(2, '0')}:'
      '${now.second.toString().padLeft(2, '0')}';
}

/// Format timestamp for filenames (no colons): yyyy-MM-dd_HH-mm-ss
String formatTimestampFileName([DateTime? dt]) {
  final now = dt ?? DateTime.now();
  return '${now.year}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}_'
      '${now.hour.toString().padLeft(2, '0')}-'
      '${now.minute.toString().padLeft(2, '0')}-'
      '${now.second.toString().padLeft(2, '0')}';
}

/// Validate MAC address format: XX-XX-XX-XX-XX-XX or XX:XX:XX:XX:XX:XX
bool isValidMacAddress(String mac) {
  final regExp = RegExp(r'^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$');
  return regExp.hasMatch(mac.trim());
}

/// Normalize MAC address: uppercase and replaces colons with dashes
String normalizeMacAddress(String mac) {
  return mac.trim().toUpperCase().replaceAll(':', '-');
}
