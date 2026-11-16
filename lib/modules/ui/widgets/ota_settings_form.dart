// lib/modules/ui/widgets/ota_settings_form.dart
// Presentational sub-widgets for the LAN OTA Settings Bento card.

import 'package:flutter/material.dart';
import '../../i18n.dart';
import '../../services/ota_update_service.dart';
import '../styles.dart';
import 'glass_update_dialog.dart';

/// Banner displaying update availability, connection errors, or up-to-date status.
class OtaResultBanner extends StatelessWidget {
  final UpdateCheckResult result;
  final AppColors colors;
  final AppStrings strings;

  const OtaResultBanner({
    super.key,
    required this.result,
    required this.colors,
    required this.strings,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;
    final s = strings;
    if (result.hasUpdate && result.packageInfo != null) {
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
                s.otaUpdateAvailable(
                    result.packageInfo!.version.displayVersion),
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
                packageInfo: result.packageInfo!,
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

    if (result.errorMessage != null) {
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
                result.errorMessage!,
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
}

/// Banner displaying SMB connection test feedback.
class OtaSmbTestBanner extends StatelessWidget {
  final bool success;
  final String message;
  final AppColors colors;

  const OtaSmbTestBanner({
    super.key,
    required this.success,
    required this.message,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final color = success ? colors.accentEmerald : colors.accentRose;
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
              message,
              style: TextStyle(fontSize: 11.5, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// SMB path, credentials, test connection button, and auto-check frequency form fields.
class OtaConfigFormFields extends StatelessWidget {
  final AppColors colors;
  final AppStrings strings;
  final TextEditingController serverPathController;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final String checkInterval;
  final bool isTestingSmb;
  final VoidCallback onTestSmb;
  final ValueChanged<String> onCheckIntervalChanged;

  const OtaConfigFormFields({
    super.key,
    required this.colors,
    required this.strings,
    required this.serverPathController,
    required this.usernameController,
    required this.passwordController,
    required this.checkInterval,
    required this.isTestingSmb,
    required this.onTestSmb,
    required this.onCheckIntervalChanged,
  });

  InputDecoration _inputDecoration(
    AppColors c, {
    String? hintText,
    EdgeInsetsGeometry contentPadding =
        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle:
          hintText != null ? TextStyle(color: c.textMuted, fontSize: 12) : null,
      filled: true,
      fillColor: c.subCardBg,
      contentPadding: contentPadding,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: c.subCardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: c.linkAccent),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = colors;
    final s = strings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
          controller: serverPathController,
          style: TextStyle(fontSize: 12.5, color: c.textPrimary),
          decoration: _inputDecoration(
            c,
            hintText: s.otaServerPathHint,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              flex: 3,
              child: _LabeledTextField(
                label: s.otaUsername,
                controller: usernameController,
                textColor: c.textPrimary,
                decoration: _inputDecoration(c, hintText: 'user'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: _LabeledTextField(
                label: s.otaPassword,
                controller: passwordController,
                textColor: c.textPrimary,
                obscureText: true,
                decoration: _inputDecoration(c, hintText: '••••'),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: isTestingSmb ? null : onTestSmb,
              icon: isTestingSmb
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.8),
                    )
                  : const Icon(Icons.lan_outlined, size: 14),
              label: Text(
                isTestingSmb ? s.otaTestingConnection : s.otaTestConnection,
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
                value: checkInterval,
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
                    onCheckIntervalChanged(val);
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LabeledTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final Color textColor;
  final bool obscureText;
  final InputDecoration decoration;

  const _LabeledTextField({
    required this.label,
    required this.controller,
    required this.textColor,
    required this.decoration,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          obscureText: obscureText,
          style: TextStyle(fontSize: 12, color: textColor),
          decoration: decoration,
        ),
      ],
    );
  }
}

/// Footer actions row for opening the OTA config folder and saving configuration.
class OtaConfigActionButtons extends StatelessWidget {
  final AppColors colors;
  final AppStrings strings;
  final bool isSaving;
  final VoidCallback onOpenConfigFolder;
  final VoidCallback onSaveConfig;

  const OtaConfigActionButtons({
    super.key,
    required this.colors,
    required this.strings,
    required this.isSaving,
    required this.onOpenConfigFolder,
    required this.onSaveConfig,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 8,
      runSpacing: 6,
      children: [
        OutlinedButton.icon(
          onPressed: onOpenConfigFolder,
          icon: const Icon(Icons.folder_open_outlined, size: 15),
          label: Text(strings.otaOpenConfigFolder),
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.textSecondary,
            side: BorderSide(color: colors.borderDefault),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
        FilledButton.icon(
          onPressed: isSaving ? null : onSaveConfig,
          icon: const Icon(Icons.save_outlined, size: 15),
          label: Text(strings.otaSaveConfig),
          style: FilledButton.styleFrom(
            backgroundColor: colors.linkAccent,
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
