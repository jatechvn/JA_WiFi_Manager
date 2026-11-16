// lib/modules/ui/widgets/monitor_kpi_row.dart
// Interactive KPI summary row and shared display status helper for MonitorTab.

import 'package:flutter/material.dart';
import '../../logic.dart';
import '../bento_widgets.dart';
import '../styles.dart';

/// Determines whether a client should be presented as blocked in the UI.
bool isClientBlockedForDisplay(ClientDevice client, bool isGuardActive) {
  return client.isBlocked ||
      client.isBlacklisted ||
      (isGuardActive && !client.isWhitelisted);
}

class MonitorBentoKpiRow extends StatelessWidget {
  final int total;
  final int allowed;
  final int blocked;
  final String selectedFilter;
  final AppColors colors;
  final bool isVi;
  final bool isZh;
  final ValueChanged<String> onSelectFilter;

  const MonitorBentoKpiRow({
    super.key,
    required this.total,
    required this.allowed,
    required this.blocked,
    required this.selectedFilter,
    required this.colors,
    required this.isVi,
    required this.isZh,
    required this.onSelectFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _InteractiveKpiCard(
            title:
                isVi ? 'Tổng kết nối' : (isZh ? '已连接设备' : 'Connected Clients'),
            value: '$total',
            subtitle: isVi
                ? 'Đang phát sóng Wi-Fi'
                : (isZh ? '活跃网络连接' : 'Active Wi-Fi clients'),
            icon: Icons.devices_rounded,
            color: colors.accentCyan,
            isSelected: selectedFilter == 'ALL',
            colors: colors,
            onTap: () => onSelectFilter('ALL'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _InteractiveKpiCard(
            title: isVi ? 'Đã duyệt' : (isZh ? '白名单允许' : 'Allowed / Secure'),
            value: '$allowed',
            subtitle: isVi
                ? 'An toàn & Tin cậy'
                : (isZh ? '受信任安全设备' : 'Verified in whitelist'),
            icon: Icons.verified_user_rounded,
            color: colors.accentEmerald,
            isSelected: selectedFilter == 'ALLOWED',
            colors: colors,
            onTap: () => onSelectFilter('ALLOWED'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _InteractiveKpiCard(
            title:
                isVi ? 'Bị chặn / Lạ' : (isZh ? '已拦截设备' : 'Blocked Intruders'),
            value: '$blocked',
            subtitle: blocked > 0
                ? (isVi ? 'Ngoài Whitelist' : 'Untrusted devices')
                : (isVi ? 'Mạng an toàn' : 'All secure'),
            icon: Icons.gpp_bad_rounded,
            color: colors.accentRose,
            isSelected: selectedFilter == 'BLOCKED',
            glow: blocked > 0,
            colors: colors,
            onTap: () => onSelectFilter('BLOCKED'),
          ),
        ),
      ],
    );
  }
}

class _InteractiveKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final bool glow;
  final VoidCallback onTap;
  final AppColors colors;

  const _InteractiveKpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isSelected,
    this.glow = false,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return BentoCard(
      colors: colors,
      onTap: onTap,
      isFeatured: isSelected || glow,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      customBorder: isSelected
          ? color.withValues(alpha: 0.65)
          : (glow ? color.withValues(alpha: 0.4) : null),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.32)),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final showFilterBadge =
                        isSelected && constraints.maxWidth >= 140;
                    return Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: colors.textMuted,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (showFilterBadge) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: color.withValues(alpha: 0.35)),
                            ),
                            child: Text(
                              'FILTER',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                                color: color,
                                fontFamily: 'Cascadia Code',
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 17,
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Cascadia Code',
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 9.5,
                    color: colors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
