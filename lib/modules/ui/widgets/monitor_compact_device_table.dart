// lib/modules/ui/widgets/monitor_compact_device_table.dart
// Compact table view and empty-state placeholder for MonitorTab.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../logic.dart';
import '../bento_widgets.dart';
import '../styles.dart';
import 'monitor_kpi_row.dart';

class MonitorCompactDeviceTable extends StatelessWidget {
  final List<ClientDevice> filtered;
  final bool isGuardActive;
  final AppColors colors;
  final bool isVi;
  final bool isZh;
  final void Function(ClientDevice) onQuickBlock;
  final void Function(ClientDevice) onQuickWhitelist;
  final void Function(String mac, String nickname) onEditNickname;
  final void Function(String) onSnackbar;

  const MonitorCompactDeviceTable({
    super.key,
    required this.filtered,
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
    return BentoCard(
      colors: colors,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: colors.subCardBg,
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  child: Text('#',
                      style: TextStyle(
                          color: colors.textMuted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('IP',
                      style: TextStyle(
                          color: colors.textMuted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  flex: 3,
                  child: Text('MAC Address',
                      style: TextStyle(
                          color: colors.textMuted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  flex: 3,
                  child: Text(isVi ? 'Tên thiết bị' : 'Device Name',
                      style: TextStyle(
                          color: colors.textMuted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold)),
                ),
                SizedBox(
                  width: 100,
                  child: Text(isVi ? 'Trạng thái' : 'Status',
                      style: TextStyle(
                          color: colors.textMuted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold)),
                ),
                SizedBox(
                  width: 70,
                  child: Text(isVi ? 'Thao tác' : 'Action',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          color: colors.textMuted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          Divider(color: colors.subCardBorder, height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, __) =>
                  Divider(color: colors.subCardBorder, height: 1),
              itemBuilder: (context, index) {
                final client = filtered[index];
                final isWhitelisted = client.isWhitelisted;
                final isBlacklisted = client.isBlacklisted;
                final isBlocked =
                    isClientBlockedForDisplay(client, isGuardActive);
                final statusColor = isBlacklisted
                    ? colors.accentRose
                    : (isWhitelisted && !client.isBlocked
                        ? colors.accentEmerald
                        : (isBlocked ? colors.accentRose : colors.accentAmber));

                return Padding(
                  key: ValueKey(client.mac),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 36,
                        child: Text('${index + 1}',
                            style: TextStyle(
                                color: colors.textMuted, fontSize: 11)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          client.ip,
                          style: TextStyle(
                            fontFamily: 'Cascadia Code',
                            fontSize: 12,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: client.mac));
                            onSnackbar('Copied MAC: ${client.mac}');
                          },
                          child: Text(
                            client.mac,
                            style: TextStyle(
                              fontFamily: 'Cascadia Code',
                              fontSize: 12,
                              color: colors.linkAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          DeviceTypeHelper.getDisplayName(
                              client.nickname, client.mac),
                          style: TextStyle(
                              color: colors.textPrimary, fontSize: 12.5),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(
                        width: 110,
                        child: PillBadge(
                          label: isBlacklisted
                              ? (isVi ? 'BỊ CẤM' : 'BLACKLISTED')
                              : (isWhitelisted && !client.isBlocked
                                  ? (isVi ? 'ĐÃ DUYỆT' : 'ALLOWED')
                                  : (isBlocked
                                      ? (isVi ? 'BỊ CHẶN' : 'BLOCKED')
                                      : (isVi ? 'CHỜ DUYỆT' : 'PENDING'))),
                          color: statusColor,
                          bg: statusColor.withValues(alpha: 0.12),
                          border: statusColor.withValues(alpha: 0.35),
                          showDot: true,
                          fontSize: 10,
                        ),
                      ),
                      SizedBox(
                        width: 80,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: isBlacklisted
                              ? IconButton(
                                  icon: Icon(Icons.verified_user_rounded,
                                      size: 16, color: colors.accentEmerald),
                                  tooltip: isVi ? 'Gỡ cấm' : 'Unblock',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                      minWidth: 28, minHeight: 28),
                                  onPressed: () => onQuickWhitelist(client),
                                )
                              : (isWhitelisted && !client.isBlocked
                                  ? IconButton(
                                      icon: Icon(Icons.block_flipped,
                                          size: 16, color: colors.accentRose),
                                      tooltip: 'Block',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                          minWidth: 28, minHeight: 28),
                                      onPressed: () => onQuickBlock(client),
                                    )
                                  : IconButton(
                                      icon: Icon(Icons.verified_user_rounded,
                                          size: 16,
                                          color: colors.accentEmerald),
                                      tooltip: 'Whitelist',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                          minWidth: 28, minHeight: 28),
                                      onPressed: () => onQuickWhitelist(client),
                                    )),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class MonitorEmptyDeviceState extends StatelessWidget {
  final AppColors colors;
  final bool isVi;
  final bool isZh;
  final bool hasFilter;
  final VoidCallback onResetFilter;

  const MonitorEmptyDeviceState({
    super.key,
    required this.colors,
    required this.isVi,
    required this.isZh,
    required this.hasFilter,
    required this.onResetFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: BentoCard(
        colors: colors,
        borderRadius: 16,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: colors.subCardBg,
                shape: BoxShape.circle,
                border: Border.all(color: colors.subCardBorder),
              ),
              child: Icon(
                hasFilter ? Icons.search_off_rounded : Icons.wifi_off_rounded,
                size: 28,
                color: colors.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              hasFilter
                  ? (isVi
                      ? 'Không tìm thấy thiết bị phù hợp'
                      : (isZh ? '没有匹配的设备' : 'No matching devices found'))
                  : (isVi
                      ? 'Chưa có thiết bị nào kết nối'
                      : (isZh ? '当前无设备连接' : 'No connected clients')),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasFilter
                  ? (isVi
                      ? 'Thử thay đổi từ khóa hoặc bộ lọc danh sách.'
                      : (isZh
                          ? '请尝试清除搜索条件或选择其他过滤器。'
                          : 'Try adjusting your search query or status filter.'))
                  : (isVi
                      ? 'Khi có thiết bị kết nối vào trạm phát Hotspot, thiết bị sẽ xuất hiện tại đây.'
                      : (isZh
                          ? '当有设备连接到移动热点时，将在此处列出。'
                          : 'Devices will appear here when connected to the mobile hotspot.')),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: colors.textMuted),
            ),
            if (hasFilter) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onResetFilter,
                icon: const Icon(Icons.refresh_rounded, size: 14),
                label: Text(isVi ? 'Đặt lại bộ lọc' : 'Reset Filter'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.linkAccent,
                  side: BorderSide(
                      color: colors.linkAccent.withValues(alpha: 0.4)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
