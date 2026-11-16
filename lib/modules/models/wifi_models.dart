// lib/modules/models/wifi_models.dart
// Domain models for WiFi Hotspot Guard (whitelist, blacklist, clients, hotspot config).

import '../utils.dart';

class WhitelistEntry {
  final String mac;
  String nickname;

  WhitelistEntry({required this.mac, required this.nickname});

  Map<String, dynamic> toJson() => {
        'mac': mac,
        'nickname': nickname,
      };
}

class BlacklistEntry {
  final String mac;
  String nickname;
  final DateTime addedAt;
  String reason;

  BlacklistEntry({
    required this.mac,
    required this.nickname,
    required this.addedAt,
    this.reason = '',
  });

  Map<String, dynamic> toJson() => {
        'mac': mac,
        'nickname': nickname,
        'addedAt': addedAt.toIso8601String(),
        'reason': reason,
      };

  factory BlacklistEntry.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    try {
      parsedDate = json['addedAt'] != null
          ? DateTime.parse(json['addedAt'].toString())
          : DateTime.now();
    } catch (_) {
      parsedDate = DateTime.now();
    }
    return BlacklistEntry(
      mac: normalizeMacAddress(json['mac']?.toString() ?? ''),
      nickname: json['nickname']?.toString() ?? '',
      addedAt: parsedDate,
      reason: json['reason']?.toString() ?? '',
    );
  }
}

class ClientDevice {
  final String ip;
  final String mac;
  final String state;
  final String nickname;
  final bool isAllowed;
  final bool isWhitelisted;
  final bool isBlocked;
  final bool isBlacklisted;

  ClientDevice({
    required this.ip,
    required this.mac,
    required this.state,
    required this.nickname,
    required this.isAllowed,
    required this.isWhitelisted,
    required this.isBlocked,
    this.isBlacklisted = false,
  });
}

class HotspotConfig {
  final String ssid;
  final String passphrase;
  final String band; // Auto, TwoPointFourGigahertz, FiveGigahertz, SixGigahertz
  final String state; // Disabled, Enabling, Enabled, Disabling, Failed
  final int maxClients;
  final int clientCount;

  HotspotConfig({
    required this.ssid,
    required this.passphrase,
    required this.band,
    required this.state,
    required this.maxClients,
    required this.clientCount,
  });

  factory HotspotConfig.fromJson(Map<String, dynamic> json) {
    return HotspotConfig(
      ssid: json['Ssid']?.toString() ?? '',
      passphrase: json['Passphrase']?.toString() ?? '',
      band: json['Band']?.toString() ?? 'Auto',
      state: json['State']?.toString() ?? 'Disabled',
      maxClients: json['MaxClients'] as int? ?? 8,
      clientCount: json['ClientCount'] as int? ?? 0,
    );
  }
}

enum HotspotOperationType {
  toggle,
  fixIcs,
  fixDhcp,
  updateConfig,
}

class HotspotBusyStatus {
  final HotspotOperationType type;
  final int stepIndex;
  final int totalSteps;
  final String phaseKey;
  final DateTime startedAt;

  const HotspotBusyStatus({
    required this.type,
    required this.stepIndex,
    required this.totalSteps,
    required this.phaseKey,
    required this.startedAt,
  });

  HotspotBusyStatus copyWith({
    int? stepIndex,
    int? totalSteps,
    String? phaseKey,
  }) {
    return HotspotBusyStatus(
      type: type,
      stepIndex: stepIndex ?? this.stepIndex,
      totalSteps: totalSteps ?? this.totalSteps,
      phaseKey: phaseKey ?? this.phaseKey,
      startedAt: startedAt,
    );
  }
}
