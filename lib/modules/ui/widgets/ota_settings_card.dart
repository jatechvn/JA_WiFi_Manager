// lib/modules/ui/widgets/ota_settings_card.dart
// Bento Frosted Glass Card for LAN OTA Update management.

import 'dart:io';
import 'package:flutter/material.dart';
import '../../constants.dart';
import '../../i18n.dart';
import '../../services/ota_update_service.dart';
import '../bento_widgets.dart';
import '../styles.dart';
import 'glass_update_dialog.dart';
import 'ota_settings_form.dart';

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
            OtaResultBanner(result: _checkResult!, colors: c, strings: s),
          ],
          if (_smbTestMessage != null) ...[
            const SizedBox(height: 8),
            OtaSmbTestBanner(
              success: _smbTestSuccess == true,
              message: _smbTestMessage ?? '',
              colors: c,
            ),
          ],
          const Divider(height: 16),
          OtaConfigFormFields(
            colors: c,
            strings: s,
            serverPathController: _serverPathController,
            usernameController: _usernameController,
            passwordController: _passwordController,
            checkInterval: _checkInterval,
            isTestingSmb: _isTestingSmb,
            onTestSmb: _testSmbConnection,
            onCheckIntervalChanged: (val) =>
                setState(() => _checkInterval = val),
          ),
          const SizedBox(height: 10),
          OtaConfigActionButtons(
            colors: c,
            strings: s,
            isSaving: _isSaving,
            onOpenConfigFolder: _openConfigFolder,
            onSaveConfig: _saveConfig,
          ),
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
}
