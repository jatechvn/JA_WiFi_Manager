// lib/modules/ui/widgets/glass_update_dialog.dart
// Frosted Glass Bento update dialog for JA WiFi Hotspot Guard

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants.dart';
import '../../i18n.dart';
import '../../services/ota_update_service.dart';
import '../styles.dart';

/// Show frosted glass OTA update dialog
Future<void> showGlassUpdateDialog({
  required BuildContext context,
  required UpdatePackageInfo packageInfo,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'GlassUpdateDialog',
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, anim1, anim2) =>
        GlassUpdateDialog(packageInfo: packageInfo),
    transitionBuilder: (ctx, anim1, anim2, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1.0).animate(
            CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      );
    },
  );
}

/// Frosted Glass update dialog widget
class GlassUpdateDialog extends StatefulWidget {
  final UpdatePackageInfo packageInfo;

  const GlassUpdateDialog({super.key, required this.packageInfo});

  @override
  State<GlassUpdateDialog> createState() => _GlassUpdateDialogState();
}

class _GlassUpdateDialogState extends State<GlassUpdateDialog> {
  bool _isUpdating = false;
  double _progress = 0.0;
  String _statusText = '';
  String? _errorMessage;

  Future<void> _startUpdate() async {
    setState(() {
      _isUpdating = true;
      _errorMessage = null;
      _progress = 0.05;
      _statusText = 'Khởi tạo...';
    });

    try {
      await OtaUpdateService().performUpdate(
        widget.packageInfo,
        onProgress: (prog, status) {
          if (mounted) {
            setState(() {
              _progress = prog;
              _statusText = status;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUpdating = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final s = context.strings;

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (!_isUpdating &&
            event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.of(context).pop();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Material(
        color: Colors.transparent,
        child: Center(
          child: Container(
            width: 520,
            margin: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: c.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: c.borderDefault.withValues(alpha: 0.3),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top highlight line
                    Container(
                      height: 1.5,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            c.glassHighlight,
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),

                    // Header Bar
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
                      decoration: BoxDecoration(
                        color: c.bgSecondary.withValues(alpha: 0.3),
                        border: Border(
                          bottom: BorderSide(
                            color: c.borderDefault.withValues(alpha: 0.2),
                            width: 0.8,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [c.linkAccent, c.accentCyan],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: c.linkAccent.withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.system_update_alt_rounded,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.otaTitle,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: c.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  s.otaUpdateAvailable(
                                    widget.packageInfo.version.displayVersion,
                                  ),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: c.accentEmerald,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!_isUpdating)
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              tooltip: s.btnClose,
                              splashRadius: 18,
                              color: c.textSecondary,
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                        ],
                      ),
                    ),

                    // Body
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Version Comparison & Package Details Card
                          Row(
                            children: [
                              // Current Version Badge
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: c.subCardBg,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: c.subCardBorder),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.otaCurrentVersion,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: c.textMuted,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'v$appVersion',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: c.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Arrow indicator
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 18,
                                color: c.textMuted,
                              ),
                              const SizedBox(width: 10),

                              // New Version Badge
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        c.accentEmerald.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: c.accentEmerald
                                          .withValues(alpha: 0.35),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Phiên bản mới',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: c.accentEmerald,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        widget
                                            .packageInfo.version.displayVersion,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: c.accentEmerald,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Metadata Chips: File Size & Release Date
                          Row(
                            children: [
                              _infoChip(
                                c: c,
                                icon: Icons.folder_zip_outlined,
                                label:
                                    '${s.otaPackageSize}: ${widget.packageInfo.formattedSize}',
                              ),
                              if (widget.packageInfo.releaseDate != null) ...[
                                const SizedBox(width: 8),
                                _infoChip(
                                  c: c,
                                  icon: Icons.calendar_today_outlined,
                                  label:
                                      '${widget.packageInfo.releaseDate!.day.toString().padLeft(2, '0')}/${widget.packageInfo.releaseDate!.month.toString().padLeft(2, '0')}/${widget.packageInfo.releaseDate!.year}',
                                ),
                              ],
                            ],
                          ),

                          // Release Notes Section
                          if (widget.packageInfo.releaseNotes != null &&
                              widget.packageInfo.releaseNotes!.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Text(
                              s.otaReleaseNotes,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: c.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              constraints: const BoxConstraints(maxHeight: 120),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: c.subCardBg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: c.subCardBorder),
                              ),
                              child: SingleChildScrollView(
                                child: Text(
                                  widget.packageInfo.releaseNotes!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.5,
                                    color: c.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ],

                          // Error Message Alert Box
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: c.accentRose.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: c.accentRose.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.error_outline_rounded,
                                    color: c.accentRose,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: c.accentRose,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Progress Bar & Status Text
                          if (_isUpdating) ...[
                            const SizedBox(height: 18),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _statusText,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: c.textPrimary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${(_progress * 100).toInt()}%',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: c.linkAccent,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: _progress,
                                    minHeight: 6,
                                    backgroundColor:
                                        c.borderDefault.withValues(alpha: 0.25),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      c.linkAccent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Actions Footer
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                      decoration: BoxDecoration(
                        color: c.bgSecondary.withValues(alpha: 0.3),
                        border: Border(
                          top: BorderSide(
                            color: c.borderDefault.withValues(alpha: 0.2),
                            width: 0.8,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (!_isUpdating) ...[
                            OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: c.textSecondary,
                                side: BorderSide(color: c.borderDefault),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 11,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(s.btnClose),
                            ),
                            const SizedBox(width: 10),
                            FilledButton.icon(
                              onPressed: _startUpdate,
                              icon: const Icon(
                                Icons.system_update_alt_rounded,
                                size: 16,
                              ),
                              label: Text(s.otaUpdateNow),
                              style: FilledButton.styleFrom(
                                backgroundColor: c.accentEmerald,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 11,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ] else ...[
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Đang thực hiện cập nhật...',
                              style: TextStyle(
                                fontSize: 12,
                                color: c.textMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoChip({
    required AppColors c,
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.subCardBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.subCardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: c.textMuted),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}
