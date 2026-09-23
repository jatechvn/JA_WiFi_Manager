// lib/modules/ui/settings_tab.dart
// Settings tab: system preferences, whitelist backup, user guide docs.

import 'dart:io';
import 'package:flutter/material.dart';
import '../logic.dart';
import '../constants.dart';
import '../i18n.dart';
import '../services/ota_update_service.dart';
import 'styles.dart';
import 'widgets/glass_update_dialog.dart';
import 'bento_widgets.dart';

class SettingsTab extends StatelessWidget {
  final WifiGuardLogic logic;
  final bool startupWithWindows;
  final ValueChanged<bool> onStartupWithWindowsChanged;
  final bool startMinimized;
  final ValueChanged<bool> onStartMinimizedChanged;
  final bool closeToTray;
  final ValueChanged<bool> onCloseToTrayChanged;
  final bool autoStartGuard;
  final ValueChanged<bool> onAutoStartGuardChanged;
  final bool autoStartHotspot;
  final ValueChanged<bool> onAutoStartHotspotChanged;
  final VoidCallback onImportWhitelist;
  final VoidCallback onExportWhitelist;
  final void Function(String message) onSnackbar;

  const SettingsTab({
    super.key,
    required this.logic,
    required this.startupWithWindows,
    required this.onStartupWithWindowsChanged,
    required this.startMinimized,
    required this.onStartMinimizedChanged,
    required this.closeToTray,
    required this.onCloseToTrayChanged,
    required this.autoStartGuard,
    required this.onAutoStartGuardChanged,
    required this.autoStartHotspot,
    required this.onAutoStartHotspotChanged,
    required this.onImportWhitelist,
    required this.onExportWhitelist,
    required this.onSnackbar,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final s = context.strings;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row of System Preferences & Whitelist Backup
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // System Preferences Bento Card
              Expanded(
                flex: 3,
                child: BentoCard(
                  colors: c,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BentoSectionHeader(
                        title: s.settingsSystemTitle,
                        icon: Icons.tune_rounded,
                        colors: c,
                      ),
                      const SizedBox(height: 8),

                      // Auto Check Interval with BentoSegmentedControl.
                      // Label sits above the pills so a narrow card cannot overflow.
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.settingsGuardInterval,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: c.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            s.settingsGuardIntervalDesc,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: c.textMuted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: BentoSegmentedControl<int>(
                              colors: c,
                              items: const [
                                BentoSegmentItem(
                                  value: 5,
                                  label: '5s',
                                  icon: Icons.bolt_rounded,
                                ),
                                BentoSegmentItem(
                                  value: 10,
                                  label: '10s',
                                  icon: Icons.timer_outlined,
                                ),
                                BentoSegmentItem(
                                  value: 30,
                                  label: '30s',
                                  icon: Icons.schedule_rounded,
                                ),
                              ],
                              groupValue: logic.checkIntervalSeconds,
                              onValueChanged: (val) {
                                logic.setCheckInterval(val);
                                onSnackbar(s.settingsIntervalUpdated(val));
                              },
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 12),

                      // Startup with Windows
                      BentoTileSwitch(
                        colors: c,
                        icon: Icons.power_settings_new_rounded,
                        iconColor: c.linkAccent,
                        title: s.settingStartup,
                        subtitle: s.settingStartupDesc,
                        value: startupWithWindows,
                        onChanged: onStartupWithWindowsChanged,
                      ),

                      // Start Minimized
                      BentoTileSwitch(
                        colors: c,
                        icon: Icons.visibility_off_rounded,
                        iconColor: c.linkAccent,
                        title: s.settingStartMinimized,
                        subtitle: s.settingStartMinimizedDesc,
                        value: startMinimized,
                        onChanged: onStartMinimizedChanged,
                      ),

                      // Close to System Tray
                      BentoTileSwitch(
                        colors: c,
                        icon: Icons.close_fullscreen_rounded,
                        iconColor: c.linkAccent,
                        title: s.settingCloseToTray,
                        subtitle: s.settingCloseToTrayDesc,
                        value: closeToTray,
                        onChanged: onCloseToTrayChanged,
                      ),

                      // Auto-start Guard Engine
                      BentoTileSwitch(
                        colors: c,
                        icon: Icons.shield_rounded,
                        iconColor: c.accentEmerald,
                        title: s.settingAutoStartGuard,
                        subtitle: s.settingAutoStartGuardDesc,
                        value: autoStartGuard,
                        onChanged: onAutoStartGuardChanged,
                      ),

                      // Auto-start Mobile Hotspot
                      BentoTileSwitch(
                        colors: c,
                        icon: Icons.wifi_tethering_rounded,
                        iconColor: c.accentCyan,
                        title: s.settingAutoStartHotspot,
                        subtitle: s.settingAutoStartHotspotDesc,
                        value: autoStartHotspot,
                        onChanged: onAutoStartHotspotChanged,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Whitelist Backup Bento Card
              Expanded(
                flex: 2,
                child: BentoCard(
                  colors: c,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BentoSectionHeader(
                        title: s.settingsBackupTitle,
                        icon: Icons.folder_zip_rounded,
                        iconColor: c.accentPurple,
                        colors: c,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        s.settingsBackupDesc,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: c.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          OutlinedButton.icon(
                            onPressed: onImportWhitelist,
                            icon: const Icon(Icons.file_open_rounded, size: 15),
                            label: Text(s.settingsImportFile),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: onExportWhitelist,
                            icon: const Icon(Icons.download_rounded, size: 15),
                            label: Text(s.settingsExportFile),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: c.accentPurple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // LAN OTA Update Card
          OtaSettingsCard(onSnackbar: onSnackbar),
          const SizedBox(height: 10),

          // User Guide Bento Card
          BentoCard(
            colors: c,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: DefaultTabController(
              length: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BentoSectionHeader(
                    title: s.settingsGuideTitle,
                    icon: Icons.menu_book_rounded,
                    colors: c,
                  ),
                  const SizedBox(height: 8),
                  TabBar(
                    labelColor: c.linkAccent,
                    unselectedLabelColor: c.textMuted,
                    indicatorColor: c.linkAccent,
                    indicatorSize: TabBarIndicatorSize.label,
                    tabs: [
                      Tab(text: s.guideTabGeneral),
                      Tab(text: s.guideTabSecurity),
                      Tab(text: s.guideTabFAQ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 160,
                    child: TabBarView(
                      children: [
                        TabDocsSection(
                          title: s.guideOverviewTitle,
                          body: s.guideOverviewContent,
                        ),
                        TabDocsSection(
                          title: s.guideSecurityTitle,
                          body: s.guideSecurityContent,
                        ),
                        TabDocsSection(
                          title: s.guideFAQTitle,
                          body: s.guideFAQContent,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TabDocsSection extends StatelessWidget {
  final String title;
  final String body;

  const TabDocsSection({
    super.key,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: c.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(fontSize: 12, color: c.textSecondary, height: 1.6),
          ),
        ],
      ),
    );
  }
}

/// Bento Frosted Glass Card for LAN OTA Update management
class OtaSettingsCard extends StatefulWidget {
  final void Function(String message) onSnackbar;

  const OtaSettingsCard({super.key, required this.onSnackbar});

  @override
  State<OtaSettingsCard> createState() => _OtaSettingsCardState();
}

class _OtaSettingsCardState extends State<OtaSettingsCard> {
  final TextEditingController _serverPathController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String _checkInterval = 'daily';
  bool _autoDownload = false;
  bool _isChecking = false;
  bool _isTestingSmb = false;
  bool _isSaving = false;
  DateTime? _lastCheckTime;
  UpdateCheckResult? _checkResult;
  bool? _smbTestSuccess;
  String? _smbTestMessage;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _serverPathController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final cfg = await OtaUpdateService().loadExternalConfigFile();
    if (mounted) {
      setState(() {
        _serverPathController.text = cfg.serverPath;
        _checkInterval = cfg.checkInterval;
        _autoDownload = cfg.autoDownload;
        _lastCheckTime = cfg.lastCheckTime;
      });
    }
  }

  Future<void> _saveConfig() async {
    setState(() => _isSaving = true);
    final cfg = OtaUpdateConfig(
      serverPath: _serverPathController.text.trim(),
      checkInterval: _checkInterval,
      autoDownload: _autoDownload,
      lastCheckTime: _lastCheckTime,
    );
    final saved = await OtaUpdateService().saveExternalConfigFile(cfg);
    final password = _passwordController.text;
    final credentialsSaved = password.isEmpty ||
        await OtaUpdateService().saveSmbCredentials(
          serverPath: cfg.serverPath,
          username: _usernameController.text.trim(),
          password: password,
        );
    if (mounted) {
      setState(() => _isSaving = false);
      widget.onSnackbar(
        saved && credentialsSaved
            ? context.strings.otaConfigSaved
            : context.strings.otaConfigSaveFailed,
      );
    }
  }

  Future<void> _testSmbConnection() async {
    setState(() {
      _isTestingSmb = true;
      _smbTestSuccess = null;
      _smbTestMessage = null;
    });

    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final hasReplacementCredentials =
        username.isNotEmpty && password.isNotEmpty;
    final success = await OtaUpdateService().connectSmbShare(
      path: _serverPathController.text.trim(),
      username: hasReplacementCredentials ? username : null,
      password: hasReplacementCredentials ? password : null,
    );

    if (mounted) {
      final s = context.strings;
      setState(() {
        _isTestingSmb = false;
        _smbTestSuccess = success;
        _smbTestMessage =
            success ? s.otaConnectionSuccess : s.otaConnectionFailed;
      });
    }
  }

  Future<void> _checkForUpdates() async {
    setState(() {
      _isChecking = true;
      _checkResult = null;
    });

    // Save inputs first
    final cfg = OtaUpdateConfig(
      serverPath: _serverPathController.text.trim(),
      checkInterval: _checkInterval,
      autoDownload: _autoDownload,
      lastCheckTime: _lastCheckTime,
    );
    if (!await OtaUpdateService().saveExternalConfigFile(cfg)) {
      if (mounted) {
        setState(() => _isChecking = false);
        widget.onSnackbar(context.strings.otaConfigSaveFailed);
      }
      return;
    }
    final password = _passwordController.text;
    if (password.isNotEmpty &&
        !await OtaUpdateService().saveSmbCredentials(
          serverPath: cfg.serverPath,
          username: _usernameController.text.trim(),
          password: password,
        )) {
      if (mounted) {
        setState(() => _isChecking = false);
        widget.onSnackbar(context.strings.otaConfigSaveFailed);
      }
      return;
    }

    final result = await OtaUpdateService().checkForUpdates(
      overrideServerPath: _serverPathController.text.trim(),
      isManual: true,
    );

    if (mounted) {
      setState(() {
        _isChecking = false;
        _checkResult = result;
        _lastCheckTime = DateTime.now();
      });

      if (result.hasUpdate && result.packageInfo != null) {
        showGlassUpdateDialog(
          context: context,
          packageInfo: result.packageInfo!,
        );
      }
    }
  }

  void _openConfigFolder() {
    final file = OtaUpdateService().getConfigFile();
    if (Platform.isWindows) {
      if (file.existsSync()) {
        Process.run('explorer.exe', ['/select,', file.path]);
      } else {
        Process.run('explorer.exe', [file.parent.path]);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final s = context.strings;

    return BentoCard(
      colors: c,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(c, s),
          const SizedBox(height: 10),
          _buildStatusRow(c, s),
          if (_checkResult != null) ...[
            const SizedBox(height: 8),
            _buildResultBanner(c, s),
          ],
          if (_smbTestMessage != null) ...[
            const SizedBox(height: 8),
            _buildSmbTestBanner(c),
          ],
          const Divider(height: 16),
          _buildForm(c, s),
          const SizedBox(height: 10),
          _buildActions(c, s),
        ],
      ),
    );
  }

  Widget _buildHeader(AppColors c, AppStrings s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StyledWidgets.sectionHeader(
          s.otaTitle,
          c,
          icon: Icons.system_update_alt_rounded,
        ),
        const SizedBox(height: 4),
        Text(
          s.otaDesc,
          style: TextStyle(fontSize: 12, color: c.textSecondary, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildStatusRow(AppColors c, AppStrings s) {
    String lastCheckedStr = s.otaNeverChecked;
    if (_lastCheckTime != null) {
      final t = _lastCheckTime!;
      final h = t.hour.toString().padLeft(2, '0');
      final m = t.minute.toString().padLeft(2, '0');
      final d = t.day.toString().padLeft(2, '0');
      final mo = t.month.toString().padLeft(2, '0');
      lastCheckedStr = '$h:$m $d/$mo/${t.year}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.subCardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.subCardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${s.otaCurrentVersion}: ',
                      style: TextStyle(fontSize: 12, color: c.textMuted),
                    ),
                    Text(
                      'v$appVersion',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: c.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${s.otaLastChecked}: $lastCheckedStr',
                  style: TextStyle(fontSize: 11, color: c.textMuted),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: _isChecking ? null : _checkForUpdates,
            icon: _isChecking
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.refresh_rounded, size: 15),
            label: Text(_isChecking ? s.otaChecking : s.otaCheckNow),
            style: FilledButton.styleFrom(
              backgroundColor: c.linkAccent,
              foregroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultBanner(AppColors c, AppStrings s) {
    final res = _checkResult!;
    if (res.hasUpdate && res.packageInfo != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.accentEmerald.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c.accentEmerald.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_rounded, size: 18, color: c.accentEmerald),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                s.otaUpdateAvailable(res.packageInfo!.version.displayVersion),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: c.accentEmerald,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => showGlassUpdateDialog(
                context: context,
                packageInfo: res.packageInfo!,
              ),
              icon: const Icon(Icons.download_rounded, size: 16),
              label: Text(s.otaUpdateNow),
              style: TextButton.styleFrom(
                foregroundColor: c.accentEmerald,
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }

    if (res.errorMessage != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.accentRose.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c.accentRose.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, size: 18, color: c.accentRose),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                res.errorMessage!,
                style: TextStyle(fontSize: 12, color: c.accentRose),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.linkAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.linkAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_rounded, size: 18, color: c.linkAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              s.otaUpToDate,
              style: TextStyle(fontSize: 12, color: c.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmbTestBanner(AppColors c) {
    final success = _smbTestSuccess == true;
    final color = success ? c.accentEmerald : c.accentRose;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            success ? Icons.check_circle_outline : Icons.warning_amber_rounded,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _smbTestMessage ?? '',
              style: TextStyle(fontSize: 11.5, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(AppColors c, AppStrings s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Server Path Field
        Text(
          s.otaServerPath,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: c.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _serverPathController,
          style: TextStyle(fontSize: 12.5, color: c.textPrimary),
          decoration: InputDecoration(
            hintText: s.otaServerPathHint,
            hintStyle: TextStyle(color: c.textMuted, fontSize: 12),
            filled: true,
            fillColor: c.subCardBg,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: c.subCardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: c.linkAccent),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Credentials & Test Connection Row
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Username
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.otaUsername,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _usernameController,
                    style: TextStyle(fontSize: 12, color: c.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'user',
                      filled: true,
                      fillColor: c.subCardBg,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: c.subCardBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: c.linkAccent),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Password
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.otaPassword,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    style: TextStyle(fontSize: 12, color: c.textPrimary),
                    decoration: InputDecoration(
                      hintText: '••••',
                      filled: true,
                      fillColor: c.subCardBg,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: c.subCardBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: c.linkAccent),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Test SMB Button
            OutlinedButton.icon(
              onPressed: _isTestingSmb ? null : _testSmbConnection,
              icon: _isTestingSmb
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.8),
                    )
                  : const Icon(Icons.lan_outlined, size: 14),
              label: Text(
                _isTestingSmb ? s.otaTestingConnection : s.otaTestConnection,
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: c.linkAccent,
                side: BorderSide(color: c.borderDefault),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Auto-check Frequency
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.otaCheckInterval,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    s.otaCheckIntervalDesc,
                    style: TextStyle(fontSize: 11, color: c.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: c.subCardBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: c.subCardBorder),
              ),
              child: DropdownButton<String>(
                value: _checkInterval,
                underline: const SizedBox(),
                dropdownColor: c.bgSecondary,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                items: [
                  DropdownMenuItem(
                      value: 'daily', child: Text(s.otaIntervalDaily)),
                  DropdownMenuItem(
                      value: 'weekly', child: Text(s.otaIntervalWeekly)),
                  DropdownMenuItem(
                      value: 'monthly', child: Text(s.otaIntervalMonthly)),
                  DropdownMenuItem(value: 'off', child: Text(s.otaIntervalOff)),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _checkInterval = val);
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActions(AppColors c, AppStrings s) {
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 8,
      runSpacing: 6,
      children: [
        OutlinedButton.icon(
          onPressed: _openConfigFolder,
          icon: const Icon(Icons.folder_open_outlined, size: 15),
          label: Text(s.otaOpenConfigFolder),
          style: OutlinedButton.styleFrom(
            foregroundColor: c.textSecondary,
            side: BorderSide(color: c.borderDefault),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
        FilledButton.icon(
          onPressed: _isSaving ? null : _saveConfig,
          icon: const Icon(Icons.save_outlined, size: 15),
          label: Text(s.otaSaveConfig),
          style: FilledButton.styleFrom(
            backgroundColor: c.linkAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ],
    );
  }
}
