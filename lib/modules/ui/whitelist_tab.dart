// lib/modules/ui/whitelist_tab.dart
// Whitelist tab: manages the security access whitelist with Bento Glassmorphic UI.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../logic.dart';
import '../i18n.dart';
import '../utils.dart';
import 'styles.dart';
import 'bento_widgets.dart';

class WhitelistTab extends StatefulWidget {
  final WifiGuardLogic logic;
  final VoidCallback onAddDevice;
  final void Function(String mac, String nickname) onEditNickname;
  final void Function(WhitelistEntry entry) onDeleteDevice;

  const WhitelistTab({
    super.key,
    required this.logic,
    required this.onAddDevice,
    required this.onEditNickname,
    required this.onDeleteDevice,
  });

  @override
  State<WhitelistTab> createState() => _WhitelistTabState();
}

class _WhitelistTabState extends State<WhitelistTab> {
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
    final allEntries = widget.logic.whitelist;

    // Check which whitelist entries are currently online
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
          entry.mac.toLowerCase().contains(_searchQuery.toLowerCase());
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
                icon: Icons.verified_user_rounded,
                iconColor: c.accentEmerald,
                label: s.whitelistTrusted,
                value: '${allEntries.length}',
                subLabel: s.whitelistTrustedDesc,
                badgeText: s.whitelistSecureBadge,
                badgeColor: c.accentEmerald,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildBentoStatCard(
                colors: c,
                icon: Icons.wifi_tethering_rounded,
                iconColor: c.linkAccent,
                label: s.whitelistOnlineStat,
                value: '$onlineCount',
                subLabel: s.whitelistOnlineStatDesc,
                badgeText: onlineCount > 0
                    ? s.whitelistActiveBadge
                    : s.whitelistIdleBadge,
                badgeColor: onlineCount > 0 ? c.linkAccent : c.textMuted,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildBentoStatCard(
                colors: c,
                icon: Icons.wifi_off_rounded,
                iconColor: c.textMuted,
                label: s.whitelistOfflineStat,
                value: '$offlineCount',
                subLabel: s.whitelistOfflineStatDesc,
                badgeText: s.whitelistStandbyBadge,
                badgeColor: c.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // 2. Action & Filter Bar (Single-row layout on desktop)
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
                  hintText: s.whitelistSearchHint,
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
                label: s.whitelistFilterOnline,
                count: onlineCount,
                isSelected: _statusFilter == 'ONLINE',
                activeColor: c.accentEmerald,
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
              icon: const Icon(Icons.add_rounded, size: 16),
              label: Text(
                s.btnAddDevice,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.accentEmerald,
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

        // 3. Whitelisted Device Cards / Bento List View
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
                            Icons.verified_user_outlined,
                            size: 32,
                            color: c.textMuted.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          s.emptyWhitelist,
                          style: TextStyle(
                            color: c.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          s.whitelistEmptyHint,
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
                          // Device Category Icon Box
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: isOnline
                                  ? c.accentEmerald.withValues(alpha: 0.12)
                                  : c.subCardBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isOnline
                                    ? c.accentEmerald.withValues(alpha: 0.3)
                                    : c.borderDefault,
                              ),
                            ),
                            child: Icon(
                              deviceIcon,
                              size: 16,
                              color:
                                  isOnline ? c.accentEmerald : c.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Device Name & Status
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
                                  isOnline
                                      ? s.whitelistConnectedNow
                                      : s.whitelistDeviceOffline,
                                  style: TextStyle(
                                    color: isOnline
                                        ? c.accentEmerald
                                        : c.textMuted,
                                    fontSize: 10.5,
                                    fontWeight: isOnline
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
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
                                  color: c.linkAccent,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  entry.mac,
                                  style: TextStyle(
                                    fontFamily: 'Cascadia Code',
                                    color: c.linkAccent,
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
                                ? s.whitelistOnlineBadge
                                : s.whitelistOfflineBadge,
                            color: isOnline ? c.accentEmerald : c.textMuted,
                            bg: isOnline
                                ? c.accentEmerald.withValues(alpha: 0.12)
                                : c.subCardBg,
                            border: isOnline
                                ? c.accentEmerald.withValues(alpha: 0.3)
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
                              // Delete from Whitelist
                              IconButton(
                                icon: Icon(
                                  Icons.delete_outline_rounded,
                                  size: 16,
                                  color: c.accentRose,
                                ),
                                tooltip: s.whitelistRemoveDevice,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: iconColor.withValues(alpha: 0.25),
                  ),
                ),
                child: Icon(icon, size: 15, color: iconColor),
              ),
              PillBadge(
                label: badgeText,
                color: badgeColor,
                bg: badgeColor.withValues(alpha: 0.10),
                border: badgeColor.withValues(alpha: 0.25),
                fontSize: 9,
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
              fontFamily: 'Cascadia Code',
              height: 1.1,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            subLabel,
            style: TextStyle(
              fontSize: 9.5,
              color: colors.textMuted,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
    Color? activeColor,
    required VoidCallback onTap,
  }) {
    final effColor = activeColor ?? colors.linkAccent;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? effColor.withValues(alpha: 0.15) : colors.cardBg,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isSelected
                ? effColor.withValues(alpha: 0.5)
                : colors.borderDefault,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? colors.textPrimary : colors.textSecondary,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? effColor : colors.subCardBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : colors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
