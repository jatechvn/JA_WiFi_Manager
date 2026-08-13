// lib/modules/ui/monitor_tab.dart
// Monitor tab widgets: tab body, client row, stat summary card.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../logic.dart';
import '../i18n.dart';
import 'styles.dart';

class MonitorTab extends StatelessWidget {
  final WifiGuardLogic logic;
  final bool hasSearchQuery;
  final void Function(ClientDevice client) onQuickBlock;
  final void Function(ClientDevice client) onQuickWhitelist;
  final void Function(String mac, String nickname) onEditNickname;
  final void Function(String message) onSnackbar;

  const MonitorTab({
    super.key,
    required this.logic,
    required this.hasSearchQuery,
    required this.onQuickBlock,
    required this.onQuickWhitelist,
    required this.onEditNickname,
    required this.onSnackbar,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final s = context.strings;
    final clients = logic.connectedClients;
    final filtered = logic.filteredConnectedClients;
    final total = clients.length;
    final allowed = clients.where((c) => c.isAllowed).length;
    final blocked = clients.where((c) => !c.isAllowed).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Grid of Stats Cards
        Row(
          children: [
            Expanded(
              child: StatCard(
                title: 'Connected Clients',
                value: '$total',
                icon: Icons.devices,
                color: c.linkAccent,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: StatCard(
                title: 'Allowed / Secure',
                value: '$allowed',
                icon: Icons.verified_user,
                color: c.statusActive,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: StatCard(
                title: 'Blocked Intruders',
                value: '$blocked',
                icon: Icons.gpp_bad,
                color: c.statusRemoved,
                glow: blocked > 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Connected clients list header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Active Hotspot Connections',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: c.textPrimary),
            ),
            if (hasSearchQuery)
              Text(
                'Found ${filtered.length} client(s)',
                style: TextStyle(
                    fontSize: 12,
                    color: c.textMuted,
                    fontStyle: FontStyle.italic),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // Connected clients Table list
        Expanded(
          child: GlassCard(
            padding: EdgeInsets.zero,
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.devices_other,
                          size: 48,
                          color: c.textMuted.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          s.emptyConnected,
                          style: TextStyle(color: c.textMuted, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      // Header Row
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        color: c.bgTertiary.withValues(alpha: 0.6),
                        child: Row(
                          children: [
                            SizedBox(
                                width: 32,
                                child:
                                    StyledWidgets.tableHeaderCell(s.colNum, c)),
                            Expanded(
                                flex: 2,
                                child: StyledWidgets.tableHeaderCell(
                                    s.colIpAddress, c)),
                            Expanded(
                                flex: 3,
                                child: StyledWidgets.tableHeaderCell(
                                    s.colMacAddress, c)),
                            Expanded(
                                flex: 3,
                                child: StyledWidgets.tableHeaderCell(
                                    s.colNickname, c)),
                            SizedBox(
                                width: 105,
                                child: StyledWidgets.tableHeaderCell(
                                    s.colStatus, c)),
                            SizedBox(
                                width: 100,
                                child: StyledWidgets.tableHeaderCell(
                                    s.colLastSeen, c)),
                            SizedBox(
                                width: 95,
                                child: StyledWidgets.tableHeaderCell(
                                    s.colActions, c,
                                    alignment: Alignment.centerRight)),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      // Data list
                      Expanded(
                        child: ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final client = filtered[index];
                            return ClientRow(
                              client: client,
                              index: index,
                              isGuardActive: logic.isGuardActive,
                              onQuickBlock: onQuickBlock,
                              onQuickWhitelist: onQuickWhitelist,
                              onEditNickname: onEditNickname,
                              onSnackbar: onSnackbar,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class ClientRow extends StatelessWidget {
  final ClientDevice client;
  final int index;
  final bool isGuardActive;
  final void Function(ClientDevice client) onQuickBlock;
  final void Function(ClientDevice client) onQuickWhitelist;
  final void Function(String mac, String nickname) onEditNickname;
  final void Function(String message) onSnackbar;

  const ClientRow({
    super.key,
    required this.client,
    required this.index,
    required this.isGuardActive,
    required this.onQuickBlock,
    required this.onQuickWhitelist,
    required this.onEditNickname,
    required this.onSnackbar,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final lang = context.languageNotifier.language;
    final isVi = lang == AppLanguage.vi;
    final isZh = lang == AppLanguage.zh;

    return Container(
      decoration: BoxDecoration(
        color: index.isEven
            ? Colors.transparent
            : c.bgSecondary.withValues(alpha: 0.1),
        border: Border(
            bottom: BorderSide(color: c.borderDefault.withValues(alpha: 0.08))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Index
          SizedBox(
            width: 32,
            child: Text('${index + 1}',
                style: TextStyle(color: c.textMuted, fontSize: 12)),
          ),
          // IP
          Expanded(
            flex: 2,
            child: Text(
              client.ip,
              style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 13,
                  fontFamily: 'Cascadia Code'),
            ),
          ),
          // MAC
          Expanded(
            flex: 3,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: client.mac));
                    onSnackbar('MAC copied: ${client.mac}');
                  },
                  child: Text(
                    client.mac,
                    style: TextStyle(
                      fontFamily: 'Cascadia Code',
                      fontSize: 12.5,
                      color: c.linkAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Tooltip(
                  message: 'Copy MAC',
                  child: InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: client.mac));
                      onSnackbar('MAC copied');
                    },
                    child: Icon(Icons.copy_all_outlined,
                        size: 12, color: c.textMuted),
                  ),
                ),
              ],
            ),
          ),
          // Nickname / Device Label
          Expanded(
            flex: 3,
            child: Text(
              client.nickname.isNotEmpty ? client.nickname : '-',
              style: TextStyle(
                color: client.nickname.isNotEmpty ? c.textPrimary : c.textMuted,
                fontSize: 13,
                fontStyle: client.nickname.isEmpty ? FontStyle.italic : null,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Status Badge
          SizedBox(
            width: 105,
            child: StyledWidgets.statusBadge(
              client.isWhitelisted
                  ? (isVi
                      ? 'ĐÃ DUYỆT'
                      : isZh
                          ? '已允许'
                          : 'ALLOWED')
                  : (isGuardActive
                      ? (isVi
                          ? 'BỊ CHẶN'
                          : isZh
                              ? '已拦截'
                              : 'BLOCKED')
                      : (isVi
                          ? 'CHƯA DUYỆT'
                          : isZh
                              ? '未允许'
                              : 'PENDING')),
              c,
            ),
          ),
          // Connection State
          SizedBox(
            width: 100,
            child: Text(
              client.state,
              style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
            ),
          ),
          // Inline Actions
          SizedBox(
            width: 110,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Quick Whitelist / Block toggle
                if (client.isWhitelisted)
                  Tooltip(
                    message: 'Block Client',
                    child: IconButton(
                      icon: Icon(Icons.block_flipped,
                          size: 16, color: c.statusRemoved),
                      onPressed: () => onQuickBlock(client),
                      style: StyledWidgets.inlineIconStyle(c.statusRemoved),
                    ),
                  )
                else
                  Tooltip(
                    message: 'Whitelist Client',
                    child: IconButton(
                      icon: Icon(Icons.add_moderator_outlined,
                          size: 16, color: c.statusActive),
                      onPressed: () => onQuickWhitelist(client),
                      style: StyledWidgets.inlineIconStyle(c.statusActive),
                    ),
                  ),
                const SizedBox(width: 6),
                // Edit Nickname
                Tooltip(
                  message: 'Edit Name',
                  child: IconButton(
                    icon:
                        Icon(Icons.edit_note, size: 16, color: c.statusChanged),
                    onPressed: () =>
                        onEditNickname(client.mac, client.nickname),
                    style: StyledWidgets.inlineIconStyle(c.statusChanged),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool glow;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.glow = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return GlassCard(
      padding: const EdgeInsets.all(18),
      borderColor: glow ? color.withValues(alpha: 0.35) : null,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                      fontSize: 12,
                      color: c.textMuted,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                      fontSize: 22,
                      color: c.textPrimary,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
