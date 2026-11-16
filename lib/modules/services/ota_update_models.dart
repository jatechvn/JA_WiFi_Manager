// lib/modules/services/ota_update_models.dart
// Data models and SemVer parser for the LAN OTA update service.

/// Semantic Versioning (SemVer) representation and comparison
class SemanticVersion implements Comparable<SemanticVersion> {
  final int major;
  final int minor;
  final int patch;
  final int? build;
  final String raw;
  final String? prerelease;

  const SemanticVersion({
    required this.major,
    required this.minor,
    required this.patch,
    this.build,
    required this.raw,
    this.prerelease,
  });

  /// Parse version string such as '1.1.0', 'v1.1.0', '1.1.0+2', '1.2.0-beta'
  static SemanticVersion? tryParse(String? input) {
    if (input == null || input.trim().isEmpty) return null;
    final clean = input.trim().toLowerCase().replaceAll(RegExp(r'^[vV]'), '');
    if (!RegExp(
      r'^\d+\.\d+(?:\.\d+)?(?:-[0-9a-z.-]+)?(?:\+\d+)?$',
    ).hasMatch(clean)) {
      return null;
    }
    final pre = RegExp(r'-([^+]+)').firstMatch(clean)?.group(1);

    int? buildNum;
    String versionCore = clean;
    if (clean.contains('+')) {
      final parts = clean.split('+');
      versionCore = parts[0];
      buildNum = int.tryParse(parts[1]);
    }

    if (versionCore.contains('-')) {
      versionCore = versionCore.split('-')[0];
    }

    final segments = versionCore.split('.');
    if (segments.isEmpty) return null;

    final major = int.tryParse(segments[0]);
    if (major == null) return null;
    final minor = segments.length > 1 ? int.tryParse(segments[1]) : 0;
    if (minor == null) return null;
    final patch = segments.length > 2 ? int.tryParse(segments[2]) : 0;
    if (patch == null) return null;

    return SemanticVersion(
      major: major,
      minor: minor,
      patch: patch,
      build: buildNum,
      raw: input.trim(),
      prerelease: pre,
    );
  }

  @override
  int compareTo(SemanticVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);
    if (prerelease != other.prerelease) {
      if (prerelease == null) return 1;
      if (other.prerelease == null) return -1;
      final a = prerelease!.split('.');
      final b = other.prerelease!.split('.');
      for (var i = 0; i < a.length && i < b.length; i++) {
        final x = int.tryParse(a[i]);
        final y = int.tryParse(b[i]);
        final comparison = x != null && y != null
            ? x.compareTo(y)
            : x != null
                ? -1
                : y != null
                    ? 1
                    : a[i].compareTo(b[i]);
        if (comparison != 0) return comparison;
      }
      if (a.length != b.length) return a.length.compareTo(b.length);
    }
    final b1 = build ?? 0;
    final b2 = other.build ?? 0;
    return b1.compareTo(b2);
  }

  bool operator >(SemanticVersion other) => compareTo(other) > 0;
  bool operator <(SemanticVersion other) => compareTo(other) < 0;
  bool operator >=(SemanticVersion other) => compareTo(other) >= 0;
  bool operator <=(SemanticVersion other) => compareTo(other) <= 0;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SemanticVersion && compareTo(other) == 0;
  }

  @override
  int get hashCode => Object.hash(major, minor, patch, build ?? 0, prerelease);

  @override
  String toString() {
    final base =
        '$major.$minor.$patch${prerelease == null ? '' : '-$prerelease'}';
    return build != null && build! > 0 ? '$base+$build' : base;
  }

  String get displayVersion => 'v$this';
}

/// Metadata describing an available update package
class UpdatePackageInfo {
  final SemanticVersion version;
  final String fileName;
  final String fullPath;
  final int fileSize;
  final String sha256;
  final String? releaseNotes;
  final DateTime? releaseDate;

  const UpdatePackageInfo({
    required this.version,
    required this.fileName,
    required this.fullPath,
    required this.fileSize,
    required this.sha256,
    this.releaseNotes,
    this.releaseDate,
  });

  String get formattedSize {
    if (fileSize <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double size = fileSize.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(i == 0 ? 0 : 2)} ${suffixes[i]}';
  }
}

/// Result of checking for updates
class UpdateCheckResult {
  final bool hasUpdate;
  final UpdatePackageInfo? packageInfo;
  final String currentVersion;
  final String? errorMessage;
  final bool isConnectionSuccess;

  const UpdateCheckResult({
    required this.hasUpdate,
    this.packageInfo,
    required this.currentVersion,
    this.errorMessage,
    this.isConnectionSuccess = true,
  });
}

/// Configuration settings for OTA updates stored in update_config.json
class OtaUpdateConfig {
  final String serverPath;
  final String checkInterval; // 'daily', 'weekly', 'monthly', 'off'
  final bool autoDownload;
  final DateTime? lastCheckTime;
  final String? cachedUpdateVersion;

  const OtaUpdateConfig({
    required this.serverPath,
    this.checkInterval = 'daily',
    this.autoDownload = false,
    this.lastCheckTime,
    this.cachedUpdateVersion,
  });

  factory OtaUpdateConfig.defaults() => const OtaUpdateConfig(
        serverPath:
            r'\\10.81.141.226\temp\FBT\JA_PROJECT\JA_Update\JA_WiFi_Manager',
        checkInterval: 'daily',
        autoDownload: false,
      );

  factory OtaUpdateConfig.fromJson(Map<String, dynamic> json) {
    return OtaUpdateConfig(
      serverPath: json['serverPath'] as String? ??
          r'\\10.81.141.226\temp\FBT\JA_PROJECT\JA_Update\JA_WiFi_Manager',
      checkInterval: json['checkInterval'] as String? ?? 'daily',
      autoDownload: json['autoDownload'] as bool? ?? false,
      lastCheckTime: json['lastCheckTime'] != null
          ? DateTime.tryParse(json['lastCheckTime'] as String)
          : null,
      cachedUpdateVersion: json['cachedUpdateVersion'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'serverPath': serverPath,
        'checkInterval': checkInterval,
        'autoDownload': autoDownload,
        if (lastCheckTime != null)
          'lastCheckTime': lastCheckTime!.toIso8601String(),
        if (cachedUpdateVersion != null)
          'cachedUpdateVersion': cachedUpdateVersion,
      };

  OtaUpdateConfig copyWith({
    String? serverPath,
    String? checkInterval,
    bool? autoDownload,
    DateTime? lastCheckTime,
    String? cachedUpdateVersion,
  }) {
    return OtaUpdateConfig(
      serverPath: serverPath ?? this.serverPath,
      checkInterval: checkInterval ?? this.checkInterval,
      autoDownload: autoDownload ?? this.autoDownload,
      lastCheckTime: lastCheckTime ?? this.lastCheckTime,
      cachedUpdateVersion: cachedUpdateVersion ?? this.cachedUpdateVersion,
    );
  }
}
