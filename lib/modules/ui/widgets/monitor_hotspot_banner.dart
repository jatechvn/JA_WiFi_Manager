// lib/modules/ui/widgets/monitor_hotspot_banner.dart
// Quick Hotspot toggle, ICS recovery, and navigation banner for MonitorTab.

import 'package:flutter/material.dart';
import '../../i18n.dart';
import '../../logic.dart';
import '../bento_widgets.dart';
import '../styles.dart';
import 'hotspot_operation_progress_banner.dart';

class MonitorHotspotQuickControlBanner extends StatefulWidget {
  final WifiGuardLogic logic;
  final AppColors colors;
  final bool isVi;
  final bool isZh;
  final void Function(String message) onSnackbar;
  final ValueChanged<String>? onNavigateToTab;

  const MonitorHotspotQuickControlBanner({
    super.key,
    required this.logic,
    required this.colors,
    required this.isVi,
    required this.isZh,
    required this.onSnackbar,
    this.onNavigateToTab,
  });

  @override
  State<MonitorHotspotQuickControlBanner> createState() =>
      _MonitorHotspotQuickControlBannerState();
}

class _MonitorHotspotQuickControlBannerState
    extends State<MonitorHotspotQuickControlBanner> {
  bool _isToggling = false;
  bool _isFixingIcs = false;

  bool get _isBusy => _isToggling || _isFixingIcs || widget.logic.isHotspotBusy;

  Future<void> _onToggleHotspot(bool val) async {
    if (_isBusy) return;
    setState(() => _isToggling = true);
    final ok = await widget.logic.setHotspotState(val);
    if (!mounted) return;
    setState(() => _isToggling = false);
    if (ok) {
      widget.onSnackbar(widget.isVi
          ? 'Đã chuyển đổi trạng thái Hotspot'
          : (widget.isZh ? '已切换移动热点状态' : 'Hotspot state changed'));
    } else {
      widget.onSnackbar(
        widget.isVi
            ? 'Chuyển đổi Hotspot thất bại!'
            : (widget.isZh ? '热点切换失败！' : 'Failed to toggle hotspot!'),
      );
    }
  }

  Future<void> _onFixIcs() async {
    if (_isBusy) return;
    setState(() => _isFixingIcs = true);
    widget.onSnackbar(widget.isVi
        ? 'Đang khởi động lại dịch vụ ICS an toàn...'
        : (widget.isZh
            ? '正在安全重启ICS服务...'
            : 'Safely restarting SharedAccess...'));
    final ok = await widget.logic.repairIcsService();
    if (!mounted) return;
    setState(() => _isFixingIcs = false);
    if (ok) {
      widget.onSnackbar(widget.isVi
          ? 'Dịch vụ đã phục hồi. Hãy bật Hotspot và kiểm tra thiết bị nhận IP.'
          : (widget.isZh
              ? '服务已恢复。请开启热点并验证客户端 DHCP。'
              : 'Services recovered. Turn Hotspot on and verify client DHCP.'));
    } else {
      widget.onSnackbar(
        widget.logic.icsRepairError ??
            (widget.isVi
                ? 'Khởi động lại dịch vụ ICS thất bại!'
                : (widget.isZh
                    ? 'ICS服务重启失败！'
                    : 'Failed to restart ICS service!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.logic.hotspotConfig;
    final isHotspotOn = config?.state.toLowerCase() == 'enabled';
    final ssid = config?.ssid.isNotEmpty == true
        ? config!.ssid
        : (widget.isVi ? 'Hotspot Chưa Cấu Hình' : 'Mobile Hotspot');

    final bandText = config?.band != null
        ? (config!.band == 'TwoPointFourGigahertz'
            ? '2.4 GHz'
            : (config.band == 'FiveGigahertz'
                ? '5.0 GHz'
                : (config.band == 'SixGigahertz' ? '6.0 GHz' : config.band)))
        : 'Auto';

    final language = widget.isVi
        ? AppLanguage.vi
        : (widget.isZh ? AppLanguage.zh : AppLanguage.en);
    final fallbackType = _isFixingIcs
        ? HotspotOperationType.fixIcs
        : (_isToggling ? HotspotOperationType.toggle : null);

    return BentoCard(
      colors: widget.colors,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isHotspotOn
                      ? widget.colors.accentEmerald.withValues(alpha: 0.14)
                      : widget.colors.subCardBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isHotspotOn
                        ? widget.colors.accentEmerald.withValues(alpha: 0.35)
                        : widget.colors.subCardBorder,
                  ),
                ),
                child: Icon(
                  Icons.wifi_tethering_rounded,
                  color: isHotspotOn
                      ? widget.colors.accentEmerald
                      : widget.colors.textMuted,
                  size: 17,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            ssid,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: widget.colors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        PillBadge(
                          label: isHotspotOn ? 'ONLINE' : 'OFFLINE',
                          color: isHotspotOn
                              ? widget.colors.accentEmerald
                              : widget.colors.textMuted,
                          bg: isHotspotOn
                              ? widget.colors.accentEmerald
                                  .withValues(alpha: 0.12)
                              : widget.colors.subCardBg,
                          border: isHotspotOn
                              ? widget.colors.accentEmerald
                                  .withValues(alpha: 0.35)
                              : widget.colors.subCardBorder,
                          showDot: true,
                          fontSize: 9.5,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1.5),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: widget.colors.subCardBg,
                            borderRadius: BorderRadius.circular(4),
                            border:
                                Border.all(color: widget.colors.subCardBorder),
                          ),
                          child: Text(
                            bandText,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: widget.colors.textSecondary,
                              fontFamily: 'Cascadia Code',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isHotspotOn
                          ? (widget.isVi
                              ? 'Đang phát • DHCP: ${config?.clientCount ?? 0}/${config?.maxClients ?? 8} thiết bị'
                              : 'Broadcasting • DHCP: ${config?.clientCount ?? 0}/${config?.maxClients ?? 8}')
                          : (widget.isVi
                              ? 'Hotspot đang tắt. Bật switch bên phải để phát sóng.'
                              : 'Hotspot off. Toggle switch to start.'),
                      style: TextStyle(
                        fontSize: 10.5,
                        color: widget.colors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _isFixingIcs
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: widget.colors.accentAmber,
                            ),
                          ),
                        )
                      : Tooltip(
                          message: widget.isVi
                              ? 'Khởi động lại dịch vụ SharedAccess (ICS) an toàn'
                              : 'Safely restart SharedAccess (ICS) service',
                          child: InkWell(
                            key: const Key('monitor-hotspot-fix-ics'),
                            onTap: _isBusy ? null : _onFixIcs,
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: widget.colors.accentAmber
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: widget.colors.accentAmber
                                      .withValues(alpha: 0.32),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.build_circle_outlined,
                                      size: 13,
                                      color: widget.colors.accentAmber),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.isVi
                                        ? 'Sửa lỗi ICS'
                                        : (widget.isZh ? '修复ICS' : 'Fix ICS'),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: widget.colors.accentAmber,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                  const SizedBox(width: 6),
                  if (widget.onNavigateToTab != null)
                    Tooltip(
                      message: widget.isVi
                          ? 'Chuyển sang tab Cấu hình Wi-Fi'
                          : 'Configure SSID, password, and frequency band',
                      child: InkWell(
                        key: const Key('monitor-hotspot-config'),
                        onTap: () => widget.onNavigateToTab!('HOTSPOT'),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: widget.colors.subCardBg,
                            borderRadius: BorderRadius.circular(6),
                            border:
                                Border.all(color: widget.colors.subCardBorder),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.tune_rounded,
                                  size: 13, color: widget.colors.textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                widget.isVi
                                    ? 'Cấu hình'
                                    : (widget.isZh ? '配置' : 'Config'),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: widget.colors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 6),
                  _isToggling
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: Padding(
                            padding: EdgeInsets.all(3.0),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : Tooltip(
                          message: isHotspotOn
                              ? (widget.isVi
                                  ? 'Tắt Hotspot'
                                  : 'Turn Off Hotspot')
                              : (widget.isVi
                                  ? 'Bật Hotspot'
                                  : 'Turn On Hotspot'),
                          child: Transform.scale(
                            scale: 0.85,
                            child: Switch.adaptive(
                              key: const Key('monitor-hotspot-toggle'),
                              value: isHotspotOn,
                              activeThumbColor: widget.colors.accentEmerald,
                              onChanged: _isBusy ? null : _onToggleHotspot,
                            ),
                          ),
                        ),
                ],
              ),
            ],
          ),
          HotspotOperationProgressBanner(
            status: widget.logic.hotspotBusyStatus,
            fallbackType: fallbackType,
            colors: widget.colors,
            language: language,
          ),
        ],
      ),
    );
  }
}
