// lib/modules/ui/widgets/hotspot_operation_progress_banner.dart
// Inline Bento glassmorphic step-progress & elapsed timer banner for active Hotspot / ICS operations.

import 'package:flutter/material.dart';
import '../../i18n.dart';
import '../../models/wifi_models.dart';
import '../styles.dart';

class HotspotOperationProgressBanner extends StatefulWidget {
  final HotspotBusyStatus? status;
  final HotspotOperationType? fallbackType;
  final AppColors colors;
  final AppLanguage language;

  const HotspotOperationProgressBanner({
    super.key,
    required this.status,
    required this.colors,
    required this.language,
    this.fallbackType,
  });

  @override
  State<HotspotOperationProgressBanner> createState() =>
      _HotspotOperationProgressBannerState();
}

class _HotspotOperationProgressBannerState
    extends State<HotspotOperationProgressBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  DateTime? _fallbackStartedAt;

  HotspotBusyStatus? get _effectiveStatus {
    if (widget.status != null) {
      return widget.status;
    }
    final fallback = widget.fallbackType;
    if (fallback == null) return null;
    final startedAt = (_fallbackStartedAt ??= DateTime.now());
    switch (fallback) {
      case HotspotOperationType.fixIcs:
        return HotspotBusyStatus(
          type: fallback,
          stepIndex: 1,
          totalSteps: 5,
          phaseKey: 'ics_read_profile',
          startedAt: startedAt,
        );
      case HotspotOperationType.fixDhcp:
        return HotspotBusyStatus(
          type: fallback,
          stepIndex: 1,
          totalSteps: 3,
          phaseKey: 'dhcp_stop_hotspot',
          startedAt: startedAt,
        );
      case HotspotOperationType.updateConfig:
        return HotspotBusyStatus(
          type: fallback,
          stepIndex: 1,
          totalSteps: 1,
          phaseKey: 'hotspot_configuring',
          startedAt: startedAt,
        );
      case HotspotOperationType.toggle:
        return HotspotBusyStatus(
          type: fallback,
          stepIndex: 1,
          totalSteps: 1,
          phaseKey: 'hotspot_toggling',
          startedAt: startedAt,
        );
    }
  }

  void _syncTicker() {
    if (_effectiveStatus != null) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    } else {
      _fallbackStartedAt = null;
      if (_controller.isAnimating) {
        _controller.stop();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant HotspotOperationProgressBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status != null || widget.fallbackType == null) {
      _fallbackStartedAt = null;
    }
    _syncTicker();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeStatus = _effectiveStatus;
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: activeStatus == null
          ? const SizedBox.shrink()
          : Padding(
              key: const Key('hotspot-progress-banner'),
              padding: const EdgeInsets.only(top: 8),
              child: _ProgressBannerBody(
                status: activeStatus,
                colors: widget.colors,
                language: widget.language,
                animation: _controller,
              ),
            ),
    );
  }
}

class _ProgressBannerBody extends StatelessWidget {
  final HotspotBusyStatus status;
  final AppColors colors;
  final AppLanguage language;
  final Animation<double> animation;

  const _ProgressBannerBody({
    required this.status,
    required this.colors,
    required this.language,
    required this.animation,
  });

  Color get _accentColor {
    switch (status.type) {
      case HotspotOperationType.fixIcs:
        return colors.accentAmber;
      case HotspotOperationType.fixDhcp:
        return colors.linkAccent;
      case HotspotOperationType.updateConfig:
        return colors.accentPurple;
      case HotspotOperationType.toggle:
        return colors.accentEmerald;
    }
  }

  IconData get _iconData {
    switch (status.type) {
      case HotspotOperationType.fixIcs:
        return Icons.sync_rounded;
      case HotspotOperationType.fixDhcp:
        return Icons.restart_alt_rounded;
      case HotspotOperationType.updateConfig:
        return Icons.tune_rounded;
      case HotspotOperationType.toggle:
        return Icons.wifi_tethering_rounded;
    }
  }

  String _titleText() {
    final isVi = language == AppLanguage.vi;
    final isZh = language == AppLanguage.zh;
    switch (status.type) {
      case HotspotOperationType.fixIcs:
        return isVi
            ? 'Đang phục hồi dịch vụ ICS / Hotspot'
            : (isZh ? '正在恢复 ICS / 热点服务' : 'Recovering ICS / Hotspot Service');
      case HotspotOperationType.fixDhcp:
        return isVi
            ? 'Đang sửa lỗi cấp IP / DHCP Hotspot'
            : (isZh ? '正在修复热点 IP / DHCP' : 'Repairing Hotspot IP / DHCP');
      case HotspotOperationType.updateConfig:
        return isVi
            ? 'Đang áp dụng cấu hình Mobile Hotspot'
            : (isZh ? '正在应用移动热点配置' : 'Applying Mobile Hotspot Configuration');
      case HotspotOperationType.toggle:
        return isVi
            ? 'Đang chuyển đổi trạng thái Mobile Hotspot'
            : (isZh ? '正在切换移动热点状态' : 'Toggling Mobile Hotspot State');
    }
  }

  String _phaseText() {
    final isVi = language == AppLanguage.vi;
    final isZh = language == AppLanguage.zh;
    switch (status.phaseKey) {
      case 'ics_read_profile':
        return isVi
            ? 'Kiểm tra hồ sơ kết nối mạng và trạng thái Hotspot...'
            : (isZh
                ? '正在检查网络配置文件与热点状态...'
                : 'Inspecting network profile and Hotspot state...');
      case 'ics_stop_services':
        return isVi
            ? 'Đang dừng dịch vụ chia sẻ mạng (SharedAccess / ICS) an toàn...'
            : (isZh
                ? '正在安全停止共享服务 (SharedAccess / ICS)...'
                : 'Safely stopping SharedAccess / ICS services...');
      case 'ics_start_services':
        return isVi
            ? 'Đang khởi động lại dịch vụ nền SharedAccess & icssvc...'
            : (isZh
                ? '正在重启 SharedAccess 与 icssvc 后台服务...'
                : 'Starting SharedAccess & icssvc background services...');
      case 'ics_wait_stable':
        return isVi
            ? 'Đang chờ Windows ổn định card phát sóng (có thể mất 5–20 giây)...'
            : (isZh
                ? '正在等待 Windows 稳定热点虚拟网卡 (可能需要 5–20 秒)...'
                : 'Waiting for Windows Hotspot adapter to settle (5–20s)...');
      case 'ics_verify_refresh':
        return isVi
            ? 'Đang xác minh dịch vụ và đồng bộ cấu hình Hotspot...'
            : (isZh
                ? '正在验证服务状态并同步热点配置...'
                : 'Verifying services and refreshing Hotspot status...');
      case 'dhcp_stop_hotspot':
        return isVi
            ? 'Đang tắt phát sóng Hotspot trước khi sửa DHCP...'
            : (isZh
                ? '修复 DHCP 前正在停止移动热点...'
                : 'Stopping Hotspot prior to reset...');
      case 'dhcp_repair_ics':
        return isVi
            ? 'Đang khởi động lại dịch vụ chia sẻ mạng ICS (SharedAccess)...'
            : (isZh
                ? '正在重启 ICS (SharedAccess) 网络共享服务...'
                : 'Restarting Windows ICS (SharedAccess) service...');
      case 'dhcp_reset_winsock':
        return isVi
            ? 'Đang đặt lại Winsock và xóa bộ nhớ đệm DNS...'
            : (isZh
                ? '正在重置 Winsock 并刷新 DNS 缓存...'
                : 'Resetting Winsock and flushing DNS cache...');
      case 'hotspot_enabling':
        return isVi
            ? 'Đang kích hoạt bộ phát Mobile Hotspot của Windows...'
            : (isZh
                ? '正在启动 Windows 移动热点...'
                : 'Starting Windows Mobile Hotspot tethering...');
      case 'hotspot_disabling':
        return isVi
            ? 'Đang tắt bộ phát Mobile Hotspot an toàn...'
            : (isZh
                ? '正在安全关闭 Windows 移动热点...'
                : 'Stopping Windows Mobile Hotspot tethering...');
      case 'hotspot_configuring':
        return isVi
            ? 'Đang lưu tên mạng (SSID), mật khẩu và băng tần...'
            : (isZh
                ? '正在向系统写入热点名称、密码与频段配置...'
                : 'Saving SSID, passphrase, and Wi-Fi band settings...');
      default:
        return isVi
            ? 'Đang xử lý tác vụ hệ thống Windows...'
            : (isZh
                ? '正在与 Windows 系统同步操作...'
                : 'Processing Windows Hotspot operation...');
    }
  }

  String _stepBadgeText() {
    if (language == AppLanguage.vi) {
      return 'Bước ${status.stepIndex}/${status.totalSteps}';
    }
    if (language == AppLanguage.zh) {
      return '步骤 ${status.stepIndex}/${status.totalSteps}';
    }
    return 'Step ${status.stepIndex}/${status.totalSteps}';
  }

  String _formatElapsed(DateTime startedAt) {
    final secs = DateTime.now().difference(startedAt).inSeconds.clamp(0, 3599);
    final mm = (secs ~/ 60).toString().padLeft(2, '0');
    final ss = (secs % 60).toString().padLeft(2, '0');
    return '$mm:${ss}s';
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor;
    final hasMultiStep = status.totalSteps > 1;
    final targetProgress = hasMultiStep
        ? (status.stepIndex / status.totalSteps).clamp(0.08, 1.0)
        : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              RotationTransition(
                turns: animation,
                child: Icon(_iconData, size: 15, color: accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _titleText(),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (hasMultiStep) ...[
                const SizedBox(width: 6),
                _StatusChip(
                  text: _stepBadgeText(),
                  accent: accent,
                ),
              ],
              const SizedBox(width: 6),
              AnimatedBuilder(
                animation: animation,
                builder: (context, _) => _StatusChip(
                  key: const Key('hotspot-progress-elapsed'),
                  text: _formatElapsed(status.startedAt),
                  accent: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            _phaseText(),
            style: TextStyle(fontSize: 10.5, color: colors.textSecondary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: targetProgress != null
                ? TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                    tween: Tween<double>(end: targetProgress),
                    builder: (context, value, _) => LinearProgressIndicator(
                      value: value,
                      minHeight: 4,
                      backgroundColor: accent.withValues(alpha: 0.16),
                      valueColor: AlwaysStoppedAnimation<Color>(accent),
                    ),
                  )
                : LinearProgressIndicator(
                    minHeight: 4,
                    backgroundColor: accent.withValues(alpha: 0.16),
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String text;
  final Color accent;

  const _StatusChip({
    super.key,
    required this.text,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: accent,
          fontFamily: 'Cascadia Code',
        ),
      ),
    );
  }
}
