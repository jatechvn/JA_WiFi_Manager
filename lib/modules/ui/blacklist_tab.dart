// lib/modules/ui/blacklist_tab.dart
// Blacklist tab: manages blocked/forbidden devices with Bento Glassmorphic UI.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../logic.dart';
import '../i18n.dart';
import '../utils.dart';
import 'styles.dart';
import 'bento_widgets.dart';

class BlacklistTab extends StatefulWidget {
  final WifiGuardLogic logic;
  final VoidCallback onAddDevice;
  final void Function(String mac, String nickname) onEditNickname;
  final void Function(BlacklistEntry entry) onDeleteDevice;
  final void Function(BlacklistEntry entry) onMoveToWhitelist;

  const BlacklistTab({
    super.key,
    required this.logic,
    required this.onAddDevice,
    required this.onEditNickname,
    required this.onDeleteDevice,
    required this.onMoveToWhitelist,
  });

  @override
  State<BlacklistTab> createState() => _BlacklistTabState();
}

class _BlacklistTabState extends State<BlacklistTab> {
  String _searchQuery = '';
  String _statusFilter = 'ALL'; // 'ALL', 'ONLINE', 'OFFLINE'
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final s = context.strings;
    final allEntries = widget.logic.blacklist;

    // Check which blacklist entries are currently online
    final connectedMacs = widget.logic.connectedClients
        .map((cl) => normalizeMacAddress(cl.mac))
        .toSet();

    final onlineCount = allEntries
        .where((e) => connectedMacs.contains(normalizeMacAddress(e.mac)))
        .length;
    final offlineCount = allEntries.length - onlineCount;

    // Filter by search & status
    final filtered = allEntries.where((entry) {
      final matchesSearch = _searchQuery.isEmpty ||
          entry.nickname.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          entry.mac.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          entry.reason.toLowerCase().contains(_searchQuery.toLowerCase());
      if (!matchesSearch) return false;

      final isOnline = connectedMacs.contains(normalizeMacAddress(entry.mac));
      if (_statusFilter == 'ONLINE') return isOnline;
      if (_statusFilter == 'OFFLINE') return !isOnline;
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Bento Stat Cards Overview
        Row(
          children: [
            Expanded(
              child: _buildBentoStatCard(
                colors: c,
                icon: Icons.block_rounded,
                iconColor: c.accentRose,
                label: context.languageNotifier.language == AppLanguage.vi
                    ? 'Danh Sách Đen'
                    : context.languageNotifier.language == AppLanguage.zh
                        ? '黑名单总数'
                        : 'Total Blacklisted',
                value: '${allEntries.length}',
                subLabel: context.languageNotifier.language == AppLanguage.vi
                    ? 'Thiết bị bị cấm truy cập'
                    : context.languageNotifier.language == AppLanguage.zh
                        ? '已被完全禁止访问'
                        : 'Blocked devices',
                badgeText: 'STRICT',
                badgeColor: c.accentRose,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildBentoStatCard(
                colors: c,
                icon: Icons.gpp_bad_rounded,
                iconColor: onlineCount > 0 ? c.accentRose : c.textMuted,
                label: context.languageNotifier.language == AppLanguage.vi
                    ? 'Đang Chặn Trực Tiếp'
                    : context.languageNotifier.language == AppLanguage.zh
                        ? '当前在线拦截'
                        : 'Active Interceptions',
                value: '$onlineCount',
                subLabel: context.languageNotifier.language == AppLanguage.vi
                    ? 'Đang kết nối & bị khóa'
                    : context.languageNotifier.language == AppLanguage.zh
                        ? '设备在线并被封锁'
                        : 'Blocked in real-time',
                badgeText: onlineCount > 0 ? 'BLOCKED' : 'CLEAN',
                badgeColor: onlineCount > 0 ? c.accentRose : c.accentEmerald,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildBentoStatCard(
                colors: c,
                icon: Icons.shield_moon_rounded,
                iconColor: c.textMuted,
                label: context.languageNotifier.language == AppLanguage.vi
                    ? 'Ngoại Tuyến'
                    : context.languageNotifier.language == AppLanguage.zh
                        ? '离线设备'
                        : 'Offline Devices',
                value: '$offlineCount',
                subLabel: context.languageNotifier.language == AppLanguage.vi
                    ? 'Sẽ chặn ngay khi kết nối'
                    : context.languageNotifier.language == AppLanguage.zh
                        ? '一旦接入立即封锁'
                        : 'Armed on connect',
                badgeText: 'ARMED',
                badgeColor: c.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // 2. Action & Filter Bar
        LayoutBuilder(
          builder: (context, constraints) {
            final isSingleRow = constraints.maxWidth >= 580;

            final searchBox = Container(
              height: 34,
              decoration: BoxDecoration(
                color: c.cardBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: c.borderDefault),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                style: TextStyle(color: c.textPrimary, fontSize: 12.5),
                decoration: InputDecoration(
                  hintText: context.languageNotifier.language == AppLanguage.vi
                      ? 'Tìm theo tên, MAC, lý do...'
                      : context.languageNotifier.language == AppLanguage.zh
                          ? '搜索名称、MAC 或原因...'
                          : 'Search name, MAC, reason...',
                  hintStyle: TextStyle(color: c.textMuted, fontSize: 11.5),
                  prefixIcon: Icon(Icons.search, size: 16, color: c.textMuted),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 14),
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 24, minHeight: 24),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            );

            final chips = [
              _buildFilterChip(
                colors: c,
                label: s.whitelistFilterAll,
                count: allEntries.length,
                isSelected: _statusFilter == 'ALL',
                onTap: () => setState(() => _statusFilter = 'ALL'),
              ),
              _buildFilterChip(
                colors: c,
                label: context.languageNotifier.language == AppLanguage.vi
                    ? 'Bị chặn trực tiếp'
                    : context.languageNotifier.language == AppLanguage.zh
                        ? '拦截中'
                        : 'Blocked Now',
                count: onlineCount,
                isSelected: _statusFilter == 'ONLINE',
                activeColor: c.accentRose,
                onTap: () => setState(() => _statusFilter = 'ONLINE'),
              ),
              _buildFilterChip(
                colors: c,
                label: s.whitelistFilterOffline,
                count: offlineCount,
                isSelected: _statusFilter == 'OFFLINE',
                onTap: () => setState(() => _statusFilter = 'OFFLINE'),
              ),
            ];

            final addBtn = ElevatedButton.icon(
              onPressed: widget.onAddDevice,
              icon: const Icon(Icons.add_moderator_rounded, size: 16),
              label: Text(
                s.btnAddToBlacklist,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.accentRose,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
            );

            if (isSingleRow) {
              return Row(
                children: [
                  SizedBox(width: 180, child: searchBox),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: chips
                            .map((chip) => Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: chip,
                                ))
                            .toList(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  addBtn,
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                searchBox,
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ...chips,
                    addBtn,
                  ],
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),

        // 3. Blacklisted Device Cards / Bento List View
        Expanded(
          child: filtered.isEmpty
              ? BentoCard(
                  colors: c,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: c.subCardBg,
                            shape: BoxShape.circle,
                            border: Border.all(color: c.borderDefault),
                          ),
                          child: Icon(
                            Icons.security_rounded,
                            size: 32,
                            color: c.textMuted.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          s.emptyBlacklist,
                          style: TextStyle(
                            color: c.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          context.languageNotifier.language == AppLanguage.vi
                              ? 'Các thiết bị lạ khi phát hiện có thể đưa vào đây để luôn bị chặn.'
                              : context.languageNotifier.language ==
                                      AppLanguage.zh
                                  ? '可疑或未经授权的设备加入黑名单后将被永久拦截。'
                                  : 'Suspicious devices added here will be strictly blocked.',
                          style: TextStyle(color: c.textMuted, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final entry = filtered[index];
                    final isOnline =
                        connectedMacs.contains(normalizeMacAddress(entry.mac));
                    final deviceIcon = DeviceTypeHelper.getDeviceIcon(
                      entry.nickname,
                      '',
                    );

                    return BentoCard(
                      colors: c,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          // Category Icon Box
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: isOnline
                                  ? c.accentRose.withValues(alpha: 0.12)
                                  : c.subCardBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isOnline
                                    ? c.accentRose.withValues(alpha: 0.3)
                                    : c.borderDefault,
                              ),
                            ),
                            child: Icon(
                              deviceIcon,
                              size: 16,
                              color: isOnline ? c.accentRose : c.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Device Name & Reason
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        entry.nickname.isNotEmpty
                                            ? entry.nickname
                                            : s.whitelistUnnamed,
                                        style: TextStyle(
                                          color: c.textPrimary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12.5,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    InkWell(
                                      onTap: () => widget.onEditNickname(
                                        entry.mac,
                                        entry.nickname,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                      child: Padding(
                                        padding: const EdgeInsets.all(2.0),
                                        child: Icon(
                                          Icons.edit_outlined,
                                          size: 12,
                                          color: c.textMuted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  entry.reason.isNotEmpty
                                      ? entry.reason
                                      : (isOnline
                                          ? (context.languageNotifier
                                                      .language ==
                                                  AppLanguage.vi
                                              ? 'Đang kết nối & bị khóa'
                                              : 'Connected & Blocked')
                                          : (context.languageNotifier
                                                      .language ==
                                                  AppLanguage.vi
                                              ? 'Ngoại tuyến'
                                              : 'Offline')),
                                  style: TextStyle(
                                    color:
                                        isOnline ? c.accentRose : c.textMuted,
                                    fontSize: 10.5,
                                    fontWeight: isOnline
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),

                          // MAC Address Cascadia Code Chip
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: c.subCardBg,
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: c.borderDefault),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.fingerprint_rounded,
                                  size: 12,
                                  color: c.accentRose,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  entry.mac,
                                  style: TextStyle(
                                    fontFamily: 'Cascadia Code',
                                    color: c.accentRose,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                InkWell(
                                  onTap: () {
                                    Clipboard.setData(
                                      ClipboardData(text: entry.mac),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          s.whitelistMacCopied(entry.mac),
                                        ),
                                        duration:
                                            const Duration(milliseconds: 1200),
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(4),
                                  child: Icon(
                                    Icons.copy_rounded,
                                    size: 11,
                                    color: c.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Online / Offline Pill Badge
                          PillBadge(
                            label: isOnline
                                ? s.statusBlocked
                                : s.whitelistOfflineBadge,
                            color: isOnline ? c.accentRose : c.textMuted,
                            bg: isOnline
                                ? c.accentRose.withValues(alpha: 0.12)
                                : c.subCardBg,
                            border: isOnline
                                ? c.accentRose.withValues(alpha: 0.3)
                                : c.borderDefault,
                            showDot: true,
                            fontSize: 9.5,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1.5),
                          ),
                          const SizedBox(width: 10),

                          // Action Buttons
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Move to Whitelist
                              IconButton(
                                icon: Icon(
                                  Icons.verified_user_outlined,
                                  size: 16,
                                  color: c.accentEmerald,
                                ),
                                tooltip: s.btnMoveToWhitelist,
                                constraints: const BoxConstraints(
                                    minWidth: 28, minHeight: 28),
                                padding: EdgeInsets.zero,
                                onPressed: () =>
                                    widget.onMoveToWhitelist(entry),
                                style: IconButton.styleFrom(
                                  backgroundColor:
                                      c.accentEmerald.withValues(alpha: 0.1),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),

                              // Edit Nickname
                              IconButton(
                                icon: Icon(
                                  Icons.edit_note_rounded,
                                  size: 16,
                                  color: c.statusChanged,
                                ),
                                tooltip: s.whitelistEditName,
                                constraints: const BoxConstraints(
                                    minWidth: 28, minHeight: 28),
                                padding: EdgeInsets.zero,
                                onPressed: () => widget.onEditNickname(
                                  entry.mac,
                                  entry.nickname,
                                ),
                                style: IconButton.styleFrom(
                                  backgroundColor:
                                      c.statusChanged.withValues(alpha: 0.1),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),

                              // Delete from Blacklist
                              IconButton(
                                icon: Icon(
                                  Icons.delete_outline_rounded,
                                  size: 16,
                                  color: c.accentRose,
                                ),
                                tooltip: s.dlgDeleteBlacklistTitle,
                                constraints: const BoxConstraints(
                                    minWidth: 28, minHeight: 28),
                                padding: EdgeInsets.zero,
                                onPressed: () => widget.onDeleteDevice(entry),
                                style: IconButton.styleFrom(
                                  backgroundColor:
                                      c.accentRose.withValues(alpha: 0.1),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildBentoStatCard({
    required AppColors colors,
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String subLabel,
    required String badgeText,
    required Color badgeColor,
  }) {
    return BentoCard(
      colors: colors,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: iconColor.withValues(alpha: 0.25),
              ),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: colors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: badgeColor.withValues(alpha: 0.3),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                          color: badgeColor,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        subLabel,
                        style: TextStyle(
                          fontSize: 10,
                          color: colors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required AppColors colors,
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
    Color? activeColor,
  }) {
    final effectiveActiveColor = activeColor ?? colors.linkAccent;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? effectiveActiveColor.withValues(alpha: 0.15)
              : colors.cardBg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? effectiveActiveColor.withValues(alpha: 0.5)
                : colors.borderDefault,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? effectiveActiveColor : colors.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? effectiveActiveColor.withValues(alpha: 0.25)
                    : colors.subCardBg,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? effectiveActiveColor : colors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
