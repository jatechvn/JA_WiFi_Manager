// lib/modules/services/ota_update_service.dart
// LAN OTA Update Service for JA WiFi Hotspot Guard
// Handles SemVer comparison, SMB share connection, update checking, package validation, and atomic updater script execution.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../constants.dart';

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

class _SmbCredentials {
  final String username;
  final String password;

  const _SmbCredentials({required this.username, required this.password});
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

/// Service managing LAN OTA updates
class OtaUpdateService {
  static const _credentialTargetPrefix = 'JA_WiFi_Manager/OTA/SMB/';

  static bool isValidPackageName(String name) =>
      RegExp(
        r'^JA_WiFi_Manager_[a-zA-Z0-9_.+-]+\.zip$',
        caseSensitive: false,
      ).hasMatch(name) &&
      !name.contains('..');

  static bool isValidSha256(String value) =>
      RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(value);

  static String _psLiteral(String value) => "'${value.replaceAll("'", "''")}'";

  static Future<ProcessResult> _runPowerShell(String script) {
    final encoded = base64Encode(
      script.codeUnits.expand((c) => [c & 255, c >> 8]).toList(),
    );
    return Process.run('powershell.exe', [
      '-NoProfile',
      '-NonInteractive',
      '-EncodedCommand',
      encoded,
    ]);
  }

  static String? _credentialTargetForPath(String path) {
    final shareRoot = extractSmbShareRoot(path);
    if (shareRoot == null) return null;
    final serverName = shareRoot.substring(2).split('\\').first;
    return serverName.isEmpty ? null : '$_credentialTargetPrefix$serverName';
  }

  bool _applying = false;
  static final OtaUpdateService _instance = OtaUpdateService._internal();
  factory OtaUpdateService() => _instance;
  OtaUpdateService._internal();

  File? _customConfigFileForTesting;
  Directory? _customServerDirForTesting;
  OtaUpdateConfig _cachedConfig = OtaUpdateConfig.defaults();

  OtaUpdateConfig get currentConfig => _cachedConfig;

  @visibleForTesting
  void setCustomConfigFileForTesting(File? file) {
    _customConfigFileForTesting = file;
  }

  @visibleForTesting
  void setCustomServerDirForTesting(Directory? dir) {
    _customServerDirForTesting = dir;
  }

  /// Get the configuration file location:
  /// 1. Next to the executable .exe if exists (convenient for portable / LAN deploy)
  /// 2. AppData directory (%APPDATA%\JA_WiFi_Manager\update_config.json)
  File getConfigFile() {
    if (_customConfigFileForTesting != null) {
      return _customConfigFileForTesting!;
    }

    try {
      final exeDir = File(Platform.resolvedExecutable).parent;
      final exeConfig = File(
        '${exeDir.path}${Platform.pathSeparator}update_config.json',
      );
      if (exeConfig.existsSync()) {
        return exeConfig;
      }
    } catch (_) {}

    final appData = Platform.environment['APPDATA'];
    if (appData != null && appData.isNotEmpty) {
      final dir = Directory('$appData\\JA_WiFi_Manager');
      if (!dir.existsSync()) {
        try {
          dir.createSync(recursive: true);
        } catch (_) {}
      }
      return File('${dir.path}\\update_config.json');
    }
    return File('update_config.json');
  }

  /// Load configuration from update_config.json
  Future<OtaUpdateConfig> loadExternalConfigFile() async {
    try {
      final file = getConfigFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final json = jsonDecode(content) as Map<String, dynamic>;
          _cachedConfig = OtaUpdateConfig.fromJson(json);
          final legacyUsername = json['username'] as String?;
          final legacyPassword = json['password'] as String?;
          if (legacyUsername != null &&
              legacyUsername.isNotEmpty &&
              legacyPassword != null &&
              legacyPassword.isNotEmpty) {
            final migrated = await saveSmbCredentials(
              serverPath: _cachedConfig.serverPath,
              username: legacyUsername,
              password: legacyPassword,
            );
            if (!migrated) {
              debugPrint(
                '[OtaUpdateService] Could not migrate legacy SMB credential; '
                'user must enter it again.',
              );
            }
            // Scrub the plaintext secret even if migration failed.
            await saveExternalConfigFile(_cachedConfig);
          }
          return _cachedConfig;
        }
      }
    } catch (e) {
      debugPrint('[OtaUpdateService] Load config error: $e');
    }
    _cachedConfig = OtaUpdateConfig.defaults();
    return _cachedConfig;
  }

  /// Save non-secret OTA configuration to update_config.json.
  /// SMB credentials are stored separately in Windows Credential Manager.
  Future<bool> saveExternalConfigFile(OtaUpdateConfig config) async {
    try {
      final file = getConfigFile();
      final encoder = const JsonEncoder.withIndent('  ');
      await file.writeAsString(encoder.convert(config.toJson()), flush: true);
      _cachedConfig = config;
      return true;
    } catch (e) {
      debugPrint('[OtaUpdateService] Save config error: $e');
      return false;
    }
  }

  /// Save an SMB password in Windows Credential Manager, never in JSON.
  Future<bool> saveSmbCredentials({
    required String serverPath,
    required String username,
    required String password,
  }) async {
    final target = _credentialTargetForPath(serverPath);
    if (!Platform.isWindows ||
        target == null ||
        username.trim().isEmpty ||
        password.isEmpty) {
      return false;
    }

    final result = await _runPowerShell("""
\$ErrorActionPreference = 'Stop'
\$source = @'
using System;
using System.Runtime.InteropServices;
public static class JaCredentialManager {
  [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
  public struct Credential {
    public UInt32 Flags;
    public UInt32 Type;
    public string TargetName;
    public string Comment;
    public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
    public UInt32 CredentialBlobSize;
    public IntPtr CredentialBlob;
    public UInt32 Persist;
    public UInt32 AttributeCount;
    public IntPtr Attributes;
    public string TargetAlias;
    public string UserName;
  }
  [DllImport("Advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
  public static extern bool CredWrite(ref Credential credential, UInt32 flags);
}
'@
Add-Type -TypeDefinition \$source
\$secret = [Text.Encoding]::Unicode.GetBytes(${_psLiteral(password)})
\$credential = New-Object JaCredentialManager+Credential
\$credential.Type = 1
\$credential.TargetName = ${_psLiteral(target)}
\$credential.Persist = 2
\$credential.UserName = ${_psLiteral(username.trim())}
\$credential.CredentialBlobSize = \$secret.Length
\$credential.CredentialBlob = [Runtime.InteropServices.Marshal]::AllocCoTaskMem(\$secret.Length)
try {
  [Runtime.InteropServices.Marshal]::Copy(\$secret, 0, \$credential.CredentialBlob, \$secret.Length)
  if (-not [JaCredentialManager]::CredWrite([ref]\$credential, 0)) {
    throw "CredWrite failed: \$([Runtime.InteropServices.Marshal]::GetLastWin32Error())"
  }
} finally {
  [Runtime.InteropServices.Marshal]::FreeCoTaskMem(\$credential.CredentialBlob)
}
""");
    return result.exitCode == 0;
  }

  Future<_SmbCredentials?> _loadSmbCredentials(String serverPath) async {
    final target = _credentialTargetForPath(serverPath);
    if (!Platform.isWindows || target == null) return null;

    final result = await _runPowerShell("""
\$ErrorActionPreference = 'Stop'
\$source = @'
using System;
using System.Runtime.InteropServices;
public static class JaCredentialReader {
  [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
  public struct Credential {
    public UInt32 Flags;
    public UInt32 Type;
    public string TargetName;
    public string Comment;
    public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
    public UInt32 CredentialBlobSize;
    public IntPtr CredentialBlob;
    public UInt32 Persist;
    public UInt32 AttributeCount;
    public IntPtr Attributes;
    public string TargetAlias;
    public string UserName;
  }
  [DllImport("Advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
  public static extern bool CredRead(string target, UInt32 type, UInt32 flags, out IntPtr credentialPtr);
  [DllImport("Advapi32.dll", SetLastError = true)]
  public static extern void CredFree(IntPtr credentialPtr);
}
'@
Add-Type -TypeDefinition \$source
\$ptr = [IntPtr]::Zero
if (-not [JaCredentialReader]::CredRead(${_psLiteral(target)}, 1, 0, [ref]\$ptr)) { exit 2 }
try {
  \$credential = [Runtime.InteropServices.Marshal]::PtrToStructure(\$ptr, [type][JaCredentialReader+Credential])
  \$secret = New-Object byte[] \$credential.CredentialBlobSize
  [Runtime.InteropServices.Marshal]::Copy(\$credential.CredentialBlob, \$secret, 0, \$secret.Length)
  @{ username = \$credential.UserName; password = [Text.Encoding]::Unicode.GetString(\$secret) } | ConvertTo-Json -Compress
} finally {
  [JaCredentialReader]::CredFree(\$ptr)
}
""");
    if (result.exitCode != 0) return null;
    try {
      final json = jsonDecode(result.stdout.toString()) as Map<String, dynamic>;
      final username = json['username'] as String?;
      final password = json['password'] as String?;
      if (username == null || username.isEmpty || password == null) return null;
      return _SmbCredentials(username: username, password: password);
    } catch (_) {
      return null;
    }
  }

  Future<String> _calculateSha256(File file) async {
    if (!Platform.isWindows) {
      throw UnsupportedError('SHA-256 validation requires Windows');
    }
    final result = await _runPowerShell("""
\$sha256 = [Security.Cryptography.SHA256]::Create()
\$stream = [IO.File]::OpenRead(${_psLiteral(file.path)})
try {
  \$hash = \$sha256.ComputeHash(\$stream)
  [Console]::Out.Write((-join (\$hash | ForEach-Object { \$_.ToString('x2') })))
} finally {
  \$stream.Dispose()
  \$sha256.Dispose()
}
""");
    final hash = result.stdout.toString().trim().toLowerCase();
    if (result.exitCode != 0 || !isValidSha256(hash)) {
      throw StateError('Cannot calculate update package SHA-256');
    }
    return hash;
  }

  @visibleForTesting
  Future<String> calculateSha256ForTesting(File file) => _calculateSha256(file);

  /// Determine if it is time to check for updates
  bool shouldCheckForUpdates({
    required String interval,
    DateTime? lastCheckTime,
    DateTime? now,
  }) {
    if (interval == 'off') return false;
    if (lastCheckTime == null) return true;

    final currentTime = now ?? DateTime.now();
    final elapsed = currentTime.difference(lastCheckTime);

    switch (interval) {
      case 'daily':
        return elapsed.inHours >= 24;
      case 'weekly':
        return elapsed.inDays >= 7;
      case 'monthly':
        return elapsed.inDays >= 30;
      default:
        return elapsed.inHours >= 24;
    }
  }

  /// Extract root SMB share from UNC path (e.g. '\\10.81.141.226\temp')
  static String? extractSmbShareRoot(String uncPath) {
    final normalized = uncPath.replaceAll('/', '\\');
    if (!normalized.startsWith(r'\\')) return null;

    final parts = normalized.substring(2).split('\\');
    if (parts.length < 2) return null;
    return '\\\\${parts[0]}\\${parts[1]}';
  }

  /// Connect to an SMB network share via `net use` if required on Windows
  Future<bool> connectSmbShare({
    String? path,
    String? username,
    String? password,
  }) async {
    if (_customServerDirForTesting != null) {
      return await _customServerDirForTesting!.exists();
    }

    final targetPath = path ?? _cachedConfig.serverPath;
    final normalized = targetPath.replaceAll('/', '\\');
    if (!normalized.startsWith(r'\\')) {
      return await Directory(targetPath).exists();
    }

    // 1. Try accessing directly first
    try {
      if (await Directory(targetPath).exists()) {
        return true;
      }
    } catch (_) {}

    // 2. Use an in-memory PSCredential loaded from Windows Credential Manager.
    final shareRoot = extractSmbShareRoot(targetPath);
    if (shareRoot != null && Platform.isWindows) {
      try {
        final credentials = username != null && password != null
            ? _SmbCredentials(username: username, password: password)
            : await _loadSmbCredentials(targetPath);
        if (credentials == null) return false;
        final relativePath = targetPath
            .substring(shareRoot.length)
            .replaceFirst(RegExp(r'^[\\/]+'), '');
        final result = await _runPowerShell("""
\$ErrorActionPreference = 'Stop'
\$driveName = 'JaOta' + [Guid]::NewGuid().ToString('N')
\$securePassword = ConvertTo-SecureString ${_psLiteral(credentials.password)} -AsPlainText -Force
\$credential = New-Object Management.Automation.PSCredential(${_psLiteral(credentials.username)}, \$securePassword)
New-PSDrive -Name \$driveName -PSProvider FileSystem -Root ${_psLiteral(shareRoot)} -Credential \$credential | Out-Null
try {
  if (-not (Test-Path -LiteralPath (Join-Path "\$driveName`:" ${_psLiteral(relativePath)}))) { exit 3 }
} finally {
  Remove-PSDrive -Name \$driveName -Force -ErrorAction SilentlyContinue
}
""");
        return result.exitCode == 0;
      } catch (e) {
        debugPrint('[OtaUpdateService] SMB credential error: $e');
      }
    }

    return await Directory(targetPath).exists();
  }

  /// Check for updates on server
  Future<UpdateCheckResult> checkForUpdates({
    String? overrideServerPath,
    String? overrideCurrentVersion,
    bool isManual = false,
  }) async {
    final serverPath = overrideServerPath ?? _cachedConfig.serverPath;
    final currentVerStr = overrideCurrentVersion ?? appVersion;
    final currentSemVer = SemanticVersion.tryParse(currentVerStr) ??
        const SemanticVersion(major: 1, minor: 0, patch: 0, raw: '1.0.0');

    // 1. Connect to SMB server
    final connected = await connectSmbShare(path: serverPath);
    if (!connected) {
      return UpdateCheckResult(
        hasUpdate: false,
        currentVersion: currentVerStr,
        isConnectionSuccess: false,
        errorMessage:
            'Không thể kết nối hoặc truy cập thư mục máy chủ: $serverPath',
      );
    }

    // Update last checked time
    final updatedConfig = _cachedConfig.copyWith(lastCheckTime: DateTime.now());
    if (!await saveExternalConfigFile(updatedConfig)) {
      return UpdateCheckResult(
        hasUpdate: false,
        currentVersion: currentVerStr,
        errorMessage: 'Không thể lưu thời điểm kiểm tra OTA',
      );
    }

    final Directory dir = _customServerDirForTesting ?? Directory(serverPath);
    if (!await dir.exists()) {
      return UpdateCheckResult(
        hasUpdate: false,
        currentVersion: currentVerStr,
        isConnectionSuccess: false,
        errorMessage: 'Thư mục máy chủ không tồn tại: $serverPath',
      );
    }

    // 2. Check version.json if available
    final versionJsonFile = File(
      '${dir.path}${Platform.pathSeparator}version.json',
    );
    if (await versionJsonFile.exists()) {
      try {
        final content = await versionJsonFile.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        final verStr = json['version'] as String?;
        final fileName = json['fileName'] as String? ?? json['file'] as String?;
        final notes =
            json['releaseNotes'] as String? ?? json['changelog'] as String?;
        final dateStr = json['releaseDate'] as String?;
        final sha256 = (json['sha256'] as String?)?.toLowerCase();

        final serverSemVer = SemanticVersion.tryParse(verStr);
        if (serverSemVer != null &&
            fileName != null &&
            sha256 != null &&
            isValidPackageName(fileName) &&
            isValidSha256(sha256)) {
          final zipFile = File('${dir.path}${Platform.pathSeparator}$fileName');
          if (await zipFile.exists()) {
            final hasUpdate = serverSemVer > currentSemVer;
            final pkg = UpdatePackageInfo(
              version: serverSemVer,
              fileName: fileName,
              fullPath: zipFile.path,
              fileSize: await zipFile.length(),
              sha256: sha256,
              releaseNotes: notes,
              releaseDate: dateStr != null ? DateTime.tryParse(dateStr) : null,
            );
            if (hasUpdate) {
              await saveExternalConfigFile(
                _cachedConfig.copyWith(
                    cachedUpdateVersion: serverSemVer.toString()),
              );
            }
            return UpdateCheckResult(
              hasUpdate: hasUpdate,
              packageInfo: pkg,
              currentVersion: currentVerStr,
            );
          }
        }
        return UpdateCheckResult(
          hasUpdate: false,
          currentVersion: currentVerStr,
          errorMessage: 'version.json thiếu hoặc có SHA-256 không hợp lệ',
        );
      } catch (e) {
        return UpdateCheckResult(
          hasUpdate: false,
          currentVersion: currentVerStr,
          errorMessage: 'Không thể đọc version.json an toàn: $e',
        );
      }
    }

    return UpdateCheckResult(
      hasUpdate: false,
      currentVersion: currentVerStr,
      errorMessage: 'Không tìm thấy version.json có SHA-256 trên máy chủ',
    );
  }

  /// Download package, validate archive, extract, and execute update script
  Future<void> performUpdate(
    UpdatePackageInfo packageInfo, {
    void Function(double progress, String status)? onProgress,
  }) async {
    if (!Platform.isWindows) throw UnsupportedError('OTA requires Windows');
    if (_applying) throw StateError('An update is already running');
    _applying = true;
    try {
      await _performUpdate(packageInfo, onProgress: onProgress);
    } finally {
      _applying = false;
    }
  }

  Future<Directory> _performUpdate(
    UpdatePackageInfo packageInfo, {
    void Function(double progress, String status)? onProgress,
    bool prepareOnly = false,
  }) async {
    onProgress?.call(0.05, 'Khởi tạo thư mục tạm...');

    final tempBase = await Directory.systemTemp.createTemp(
      'JA_WiFi_Manager_Update_',
    );
    final localZipFile = File('${tempBase.path}/update.zip');
    final sourceZip = File(packageInfo.fullPath);
    final totalBytes = await sourceZip.length();
    if (totalBytes == 0 ||
        (packageInfo.fileSize > 0 && totalBytes != packageInfo.fileSize)) {
      throw StateError('Update package size changed; check for updates again');
    }
    final writer = localZipFile.openWrite();
    var copied = 0;
    try {
      await for (final chunk in sourceZip.openRead()) {
        writer.add(chunk);
        copied += chunk.length;
        onProgress?.call(
          (0.1 + copied / totalBytes * 0.5).clamp(0.1, 0.6),
          'Downloading update...',
        );
      }
      await writer.flush();
    } finally {
      await writer.close();
    }
    if (copied != totalBytes) throw StateError('Incomplete update package');
    final actualSha256 = await _calculateSha256(localZipFile);
    if (actualSha256 != packageInfo.sha256.toLowerCase()) {
      throw StateError('Update package checksum mismatch');
    }

    // 2. Validate and extract archive safely via PowerShell
    onProgress?.call(0.65, 'Đang giải nén gói cập nhật...');
    final extractDir = Directory('${tempBase.path}\\extracted');
    extractDir.createSync(recursive: true);

    final validation = await _runPowerShell("""
\$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
\$zip = [IO.Compression.ZipFile]::OpenRead(${_psLiteral(localZipFile.path)})
try {
  foreach (\$entry in \$zip.Entries) {
    \$parts = \$entry.FullName.Replace('\\', '/').Split('/')
    if (\$entry.FullName -match '^[\\/]' -or \$entry.FullName.Contains(':') -or \$parts -contains '..' -or ((\$entry.ExternalAttributes -shr 16) -band 61440) -eq 40960) { throw 'Unsafe archive entry' }
  }
  [IO.Compression.ZipFileExtensions]::ExtractToDirectory(\$zip, ${_psLiteral(extractDir.path)})
} finally { \$zip.Dispose() }
""");
    if (validation.exitCode != 0) {
      throw StateError('Invalid or unsafe update archive');
    }

    // 3. Locate payload directory (handling optional single root folder wrapping)
    onProgress?.call(0.85, 'Đang chuẩn bị bàn giao cập nhật...');
    Directory payloadDir = extractDir;

    final subDirs = extractDir.listSync().whereType<Directory>().toList();
    if (subDirs.length == 1) {
      final testExe = File('${subDirs.first.path}\\ja_wifi_manager.exe');
      if (testExe.existsSync()) {
        payloadDir = subDirs.first;
      }
    }

    for (final name in [
      'ja_wifi_manager.exe',
      'flutter_windows.dll',
      'data',
    ]) {
      if (!await FileSystemEntity.isFile('${payloadDir.path}/$name') &&
          !await FileSystemEntity.isDirectory('${payloadDir.path}/$name')) {
        throw StateError('Incomplete Flutter update package: $name');
      }
    }

    if (prepareOnly) return payloadDir;

    // 4. Identify current application directory and PID
    final currentExe = File(Platform.resolvedExecutable);
    final targetAppDir = currentExe.parent;
    final currentPid = pid;

    // 5. Generate apply_update.bat
    final batFile = File('${tempBase.path}\\apply_update.bat');
    final batContent = generateApplyUpdateScript(
      oldPid: currentPid,
      sourceDir: payloadDir.path,
      targetDir: targetAppDir.path,
      exeName: currentExe.path.split(Platform.pathSeparator).last,
    );
    batFile.writeAsStringSync(batContent);

    onProgress?.call(1.0, 'Sẵn sàng áp dụng cập nhật! Khởi động lại ngay...');
    await Future.delayed(const Duration(milliseconds: 600));

    // 6. Launch apply_update.bat detached and terminate this process
    if (Platform.isWindows) {
      final launch = await _runPowerShell(
        "Start-Process -FilePath 'cmd.exe' -ArgumentList ${_psLiteral('/c ""${batFile.path}""')} -WindowStyle Hidden",
      );
      if (launch.exitCode != 0) {
        throw StateError('Cannot start update installer');
      }
      exit(0);
    }
    return payloadDir;
  }

  @visibleForTesting
  Future<Directory> validatePackageForTesting(UpdatePackageInfo package) =>
      _performUpdate(package, prepareOnly: true);

  /// Generate Windows apply_update.bat script
  static String generateApplyUpdateScript({
    required int oldPid,
    required String sourceDir,
    required String targetDir,
    required String exeName,
  }) {
    for (final value in [sourceDir, targetDir, exeName]) {
      if (value.contains(RegExp(r'["%\r\n]'))) {
        throw ArgumentError('Unsupported updater path');
      }
    }
    if (oldPid <= 0 || exeName.contains(RegExp(r'[\\/]'))) {
      throw ArgumentError('Invalid updater target');
    }
    return '''@echo off
setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 >nul
title JA WiFi Hotspot Guard - Dang Cap Nhat Phien Ban Moi...

set "OLD_PID=$oldPid"
set "SRC_DIR=$sourceDir"
set "DST_DIR=$targetDir"
set "EXE_NAME=$exeName"
set "BACKUP_DIR=%~dp0backup"
if not exist "%SRC_DIR%\\%EXE_NAME%" exit /b 10
if not exist "%DST_DIR%\\%EXE_NAME%" exit /b 11
set /a WAIT_COUNT=0

echo ========================================================
echo   JA WIFI HOTSPOT GUARD - DANG TIEN HANH CAP NHAT
echo ========================================================
echo.
echo [1/3] Dang cho tien trinh cu (PID %OLD_PID%) dong han...

:wait_loop
set /a WAIT_COUNT+=1
if %WAIT_COUNT% GEQ 60 exit /b 12
timeout /t 1 /nobreak >nul
tasklist /fi "PID eq %OLD_PID%" 2>nul | findstr /i "%OLD_PID%" >nul
if not errorlevel 1 goto wait_loop

:: Cho them 1s de Windows giai phong toan bo file lock
timeout /t 1 /nobreak >nul

echo [2/3] Dang ghi de tep ung dung moi...
robocopy "%DST_DIR%" "%BACKUP_DIR%" /E /NP /R:2 /W:1 /XD logs backups /XF config.ini update_config.json whitelist.json >"%~dp0backup.log"
if errorlevel 8 exit /b 13
robocopy "%SRC_DIR%" "%DST_DIR%" /E /IS /IT /NP /R:5 /W:2 /XD logs backups /XF config.ini update_config.json whitelist.json >"%~dp0apply.log"
if errorlevel 8 goto rollback

echo [3/3] Khoi chay ung dung moi...
start "" "%DST_DIR%\\%EXE_NAME%"

:: Cho 2s roi dong cua so
timeout /t 2 /nobreak >nul
exit /b 0

:rollback
robocopy "%BACKUP_DIR%" "%DST_DIR%" /E /IS /IT /NP /R:2 /W:1 >"%~dp0rollback.log"
if errorlevel 8 exit /b 14
start "" "%DST_DIR%\\%EXE_NAME%"
exit /b 15
''';
  }
}
