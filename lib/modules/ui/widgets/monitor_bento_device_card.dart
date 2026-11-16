// lib/modules/ui/widgets/monitor_bento_device_card.dart
// Bento device card representation for connected WiFi clients in MonitorTab.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../logic.dart';
import '../bento_widgets.dart';
import '../styles.dart';
import 'monitor_kpi_row.dart';

class MonitorBentoDeviceCard extends StatelessWidget {
  final ClientDevice client;
  final bool isGuardActive;
  final AppColors colors;
  final bool isVi;
  final bool isZh;
  final void Function(ClientDevice) onQuickBlock;
  final void Function(ClientDevice) onQuickWhitelist;
  final void Function(String mac, String nickname) onEditNickname;
  final void Function(String) onSnackbar;

  const MonitorBentoDeviceCard({
    super.key,
    required this.client,
    required this.isGuardActive,
    required this.colors,
    required this.isVi,
    required this.isZh,
    required this.onQuickBlock,
    required this.onQuickWhitelist,
    required this.onEditNickname,
    required this.onSnackbar,
  });

  @override
  Widget build(BuildContext context) {
    final isWhitelisted = client.isWhitelisted;
    final isBlacklisted = client.isBlacklisted;
    final isBlocked = isClientBlockedForDisplay(client, isGuardActive);
    final displayName =
        DeviceTypeHelper.getDisplayName(client.nickname, client.mac);
    final deviceIcon =
        DeviceTypeHelper.getDeviceIcon(client.nickname, client.ip);

    final statusColor = isBlacklisted
        ? colors.accentRose
        : (isWhitelisted && !client.isBlocked
            ? colors.accentEmerald
            : (isBlocked ? colors.accentRose : colors.accentAmber));

    final statusLabel = isBlacklisted
        ? (isVi ? 'BỊ CẤM' : (isZh ? '黑名单' : 'BLACKLISTED'))
        : (isWhitelisted && !client.isBlocked
            ? (isVi ? 'ĐÃ DUYỆT' : (isZh ? '已允许' : 'ALLOWED'))
            : (isBlocked
                ? (isVi ? 'BỊ CHẶN' : (isZh ? '已拦截' : 'BLOCKED'))
                : (isVi ? 'CHỜ DUYỆT' : (isZh ? '待处理' : 'PENDING'))));

    return BentoCard(
      colors: colors,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: colors.subCardBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.subCardBorder),
            ),
            child: Icon(deviceIcon, color: statusColor, size: 16),
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
                        displayName,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => onEditNickname(client.mac, client.nickname),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.all(2.0),
                        child: Icon(
                          Icons.edit_outlined,
                          size: 12,
                          color: colors.textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    PillBadge(
                      label: statusLabel,
                      color: statusColor,
                      bg: statusColor.withValues(alpha: 0.12),
                      border: statusColor.withValues(alpha: 0.32),
                      showDot: true,
                      fontSize: 9,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1.5),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 10,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lan_rounded,
                            size: 12, color: colors.textMuted),
                        const SizedBox(width: 3),
                        Text(
                          client.ip,
                          style: TextStyle(
                            fontFamily: 'Cascadia Code',
                            fontSize: 11.5,
                            color: colors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: client.mac));
                        onSnackbar(isVi
                            ? 'Đã sao chép MAC: ${client.mac}'
                            : 'Copied MAC: ${client.mac}');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: colors.subCardBg,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: colors.subCardBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.copy_rounded,
                                size: 10, color: colors.linkAccent),
                            const SizedBox(width: 3),
                            Text(
                              client.mac,
                              style: TextStyle(
                                fontFamily: 'Cascadia Code',
                                fontSize: 11,
                                color: colors.linkAccent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: colors.accentEmerald,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          client.state.isNotEmpty ? client.state : 'Active',
                          style: TextStyle(
                              fontSize: 10.5, color: colors.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _buildActionPill(),
        ],
      ),
    );
  }

  Widget _buildActionPill() {
    if (client.isBlacklisted) {
      return _ActionPillButton(
        icon: Icons.verified_user_rounded,
        label: isVi ? 'Gỡ cấm' : (isZh ? '解除黑名单' : 'Unblock'),
        color: colors.accentEmerald,
        onTap: () => onQuickWhitelist(client),
      );
    }
    if (client.isWhitelisted && !client.isBlocked) {
      return _ActionPillButton(
        icon: Icons.block_flipped,
        label: isVi ? 'Chặn' : (isZh ? '拦截' : 'Block'),
        color: colors.accentRose,
        onTap: () => onQuickBlock(client),
      );
    }
    return _ActionPillButton(
      icon: Icons.verified_user_rounded,
      label: isVi ? 'Cho phép' : (isZh ? '允许' : 'Allow'),
      color: colors.accentEmerald,
      onTap: () => onQuickWhitelist(client),
    );
  }
}

class _ActionPillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionPillButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
