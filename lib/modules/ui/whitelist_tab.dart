// lib/modules/ui/whitelist_tab.dart
// Whitelist tab: manages the security access whitelist table.

import 'package:flutter/material.dart';
import '../logic.dart';
import '../i18n.dart';
import '../utils.dart';
import 'styles.dart';

class WhitelistTab extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final c = context.appColors;
    final s = context.strings;
    final filtered = logic.filteredWhitelist;
    final lang = context.languageNotifier.language;
    final isVi = lang == AppLanguage.vi;
    final isZh = lang == AppLanguage.zh;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Action Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Security Access Whitelist',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: c.textPrimary),
            ),
            ElevatedButton.icon(
              onPressed: onAddDevice,
              icon: const Icon(Icons.add, size: 16),
              label: Text(s.btnAddDevice),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Whitelisted Table View
        Expanded(
          child: GlassCard(
            padding: EdgeInsets.zero,
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          size: 48,
                          color: c.textMuted.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          s.emptyWhitelist,
                          style: TextStyle(color: c.textMuted, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      // Table header
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
                                flex: 3,
                                child: StyledWidgets.tableHeaderCell(
                                    s.colMacAddress, c)),
                            Expanded(
                                flex: 5,
                                child: StyledWidgets.tableHeaderCell(
                                    s.colNickname, c)),
                            SizedBox(
                                width: 100,
                                child: StyledWidgets.tableHeaderCell(
                                    s.colStatus, c)),
                            SizedBox(
                                width: 100,
                                child: StyledWidgets.tableHeaderCell(
                                    'ACTIONS', c,
                                    alignment: Alignment.centerRight)),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      // Table rows
                      Expanded(
                        child: ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final entry = filtered[index];
                            return Container(
                              decoration: BoxDecoration(
                                color: index.isEven
                                    ? Colors.transparent
                                    : c.bgSecondary.withValues(alpha: 0.1),
                                border: Border(
                                    bottom: BorderSide(
                                        color: c.borderDefault
                                            .withValues(alpha: 0.08))),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 32,
                                    child: Text('${index + 1}',
                                        style: TextStyle(
                                            color: c.textMuted, fontSize: 12)),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      entry.mac,
                                      style: TextStyle(
                                        fontFamily: 'Cascadia Code',
                                        color: c.linkAccent,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 5,
                                    child: Text(
                                      entry.nickname,
                                      style: TextStyle(
                                          color: c.textPrimary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 100,
                                    child: StyledWidgets.statusBadge(
                                      logic.connectedClients.any((cl) =>
                                              normalizeMacAddress(cl.mac) ==
                                              normalizeMacAddress(entry.mac))
                                          ? (isVi
                                              ? 'KẾT NỐI'
                                              : isZh
                                                  ? '在线'
                                                  : 'ONLINE')
                                          : (isVi
                                              ? 'NGOẠI TUYẾN'
                                              : isZh
                                                  ? '离线'
                                                  : 'OFFLINE'),
                                      c,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 100,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        // Edit Nickname
                                        IconButton(
                                          icon: Icon(Icons.edit_note,
                                              size: 16, color: c.statusChanged),
                                          onPressed: () => onEditNickname(
                                              entry.mac, entry.nickname),
                                          style: StyledWidgets.inlineIconStyle(
                                              c.statusChanged),
                                        ),
                                        const SizedBox(width: 6),
                                        // Delete Device
                                        IconButton(
                                          icon: Icon(Icons.delete_outline,
                                              size: 16, color: c.statusRemoved),
                                          onPressed: () =>
                                              onDeleteDevice(entry),
                                          style: StyledWidgets.inlineIconStyle(
                                              c.statusRemoved),
                                        ),
                                      ],
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
          ),
        ),
      ],
    );
  }
}
