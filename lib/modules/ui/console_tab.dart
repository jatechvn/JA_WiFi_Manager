// lib/modules/ui/console_tab.dart
// Console tab: Bento Glassmorphic log terminal view with level filters, search, and window chrome.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../i18n.dart';
import '../logic.dart';
import 'styles.dart';
import 'bento_widgets.dart';

class ConsoleTab extends StatefulWidget {
  final WifiGuardLogic logic;
  final ScrollController logScrollController;
  final String logLevelFilter;
  final ValueChanged<String> onLogLevelFilterChanged;
  final bool autoScrollLogs;
  final ValueChanged<bool> onAutoScrollChanged;
  final void Function(String message) onSnackbar;

  const ConsoleTab({
    super.key,
    required this.logic,
    required this.logScrollController,
    required this.logLevelFilter,
    required this.onLogLevelFilterChanged,
    required this.autoScrollLogs,
    required this.onAutoScrollChanged,
    required this.onSnackbar,
  });

  @override
  State<ConsoleTab> createState() => _ConsoleTabState();
}

class _ConsoleTabState extends State<ConsoleTab> {
  String _searchQuery = '';
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
    final rawLogs = widget.logic.logLines;

    // Count by log level
    int blockCount = 0;
    int warnCount = 0;
    int allowCount = 0;

    for (final line in rawLogs) {
      if (line.contains('[BLOCK]')) blockCount++;
      if (line.contains('[WARN]')) warnCount++;
      if (line.contains('[ALLOW]') || line.contains('[OK]')) allowCount++;
    }

    // Apply level filter and search query
    final List<String> logs = [];
    for (final line in rawLogs) {
      if (widget.logLevelFilter == 'BLOCKS' && !line.contains('[BLOCK]')) {
        continue;
      }
      if (widget.logLevelFilter == 'WARNINGS' && !line.contains('[WARN]')) {
        continue;
      }
      if (widget.logLevelFilter == 'ALLOWS' &&
          !line.contains('[ALLOW]') &&
          !line.contains('[OK]')) {
        continue;
      }
      if (_searchQuery.isNotEmpty &&
          !line.toLowerCase().contains(_searchQuery.toLowerCase())) {
        continue;
      }
      logs.add(line);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Terminal Window Chrome Header & Controls Dock
        BentoCard(
          colors: c,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            children: [
              // Window Chrome Bar
              Row(
                children: [
                  // macOS / Fedora window control dots
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF59E0B),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Console Title Pill
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: c.subCardBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: c.borderDefault),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.terminal_rounded,
                            size: 13, color: c.linkAccent),
                        const SizedBox(width: 6),
                        Text(
                          s.consoleTitle,
                          style: TextStyle(
                            fontFamily: 'Cascadia Code',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: c.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),

                  // Live Stream Status Pill
                  PillBadge(
                    label: s.consoleStreamActive,
                    color: c.accentEmerald,
                    bg: c.accentEmerald.withValues(alpha: 0.12),
                    border: c.accentEmerald.withValues(alpha: 0.3),
                    showDot: true,
                    fontSize: 10,
                  ),
                ],
              ),
              const Divider(height: 16),

              // Filter & Search Controls Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Search query in logs
                    SizedBox(
                      width: 190,
                      child: Container(
                        height: 32,
                        decoration: BoxDecoration(
                          color: c.subCardBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: c.borderDefault),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) =>
                              setState(() => _searchQuery = val.trim()),
                          style: TextStyle(color: c.textPrimary, fontSize: 12),
                          decoration: InputDecoration(
                            hintText: s.consoleSearchHint,
                            hintStyle:
                                TextStyle(color: c.textMuted, fontSize: 11),
                            prefixIcon: Icon(Icons.search,
                                size: 16, color: c.textMuted),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 14),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 7),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Filter Chips
                    _buildLogChip(
                      colors: c,
                      label: s.consoleFilterAll,
                      count: rawLogs.length,
                      isSelected: widget.logLevelFilter == 'ALL',
                      onTap: () => widget.onLogLevelFilterChanged('ALL'),
                    ),
                    const SizedBox(width: 6),
                    _buildLogChip(
                      colors: c,
                      label: s.consoleFilterBlocks,
                      count: blockCount,
                      isSelected: widget.logLevelFilter == 'BLOCKS',
                      activeColor: c.accentRose,
                      onTap: () => widget.onLogLevelFilterChanged('BLOCKS'),
                    ),
                    const SizedBox(width: 6),
                    _buildLogChip(
                      colors: c,
                      label: s.consoleFilterWarnings,
                      count: warnCount,
                      isSelected: widget.logLevelFilter == 'WARNINGS',
                      activeColor: c.accentAmber,
                      onTap: () => widget.onLogLevelFilterChanged('WARNINGS'),
                    ),
                    const SizedBox(width: 6),
                    _buildLogChip(
                      colors: c,
                      label: s.consoleFilterAllows,
                      count: allowCount,
                      isSelected: widget.logLevelFilter == 'ALLOWS',
                      activeColor: c.accentEmerald,
                      onTap: () => widget.onLogLevelFilterChanged('ALLOWS'),
                    ),
                    const SizedBox(width: 14),

                    // Auto scroll toggle
                    InkWell(
                      onTap: () =>
                          widget.onAutoScrollChanged(!widget.autoScrollLogs),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: widget.autoScrollLogs
                              ? c.linkAccent.withValues(alpha: 0.12)
                              : c.subCardBg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: widget.autoScrollLogs
                                ? c.linkAccent.withValues(alpha: 0.4)
                                : c.borderDefault,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.autoScrollLogs
                                  ? Icons.vertical_align_bottom_rounded
                                  : Icons.pause_rounded,
                              size: 14,
                              color: widget.autoScrollLogs
                                  ? c.linkAccent
                                  : c.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              s.consoleAutoScroll,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: widget.autoScrollLogs
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: widget.autoScrollLogs
                                    ? c.textPrimary
                                    : c.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Copy All Action
                    OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: rawLogs.join('\n')));
                        widget.onSnackbar(s.consoleCopied);
                      },
                      icon: const Icon(Icons.copy_rounded, size: 13),
                      label: Text(s.consoleCopy),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        textStyle: const TextStyle(fontSize: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Clear Console Action
                    OutlinedButton.icon(
                      onPressed: () async {
                        await widget.logic.clearLogs();
                        widget.onSnackbar(s.consoleCleared);
                      },
                      icon:
                          const Icon(Icons.cleaning_services_rounded, size: 13),
                      label: Text(s.consoleClear),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: c.accentRose,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        textStyle: const TextStyle(fontSize: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 2. Bento Terminal Stream Screen
        Expanded(
          child: BentoCard(
            colors: c,
            padding: const EdgeInsets.all(12),
            customBg: c.bgPrimary.withValues(alpha: 0.55),
            child: logs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 40,
                          color: c.textMuted.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          s.consoleEmpty,
                          style: TextStyle(color: c.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: widget.logScrollController,
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      Color txtColor = c.textSecondary;
                      Color? tagBg;
                      Color? tagBorder;
                      String? tagText;

                      if (log.contains('[BLOCK]')) {
                        txtColor = c.accentRose;
                        tagBg = c.accentRose.withValues(alpha: 0.15);
                        tagBorder = c.accentRose.withValues(alpha: 0.3);
                        tagText = 'BLOCK';
                      } else if (log.contains('[ALLOW]') ||
                          log.contains('[OK]')) {
                        txtColor = c.accentEmerald;
                        tagBg = c.accentEmerald.withValues(alpha: 0.15);
                        tagBorder = c.accentEmerald.withValues(alpha: 0.3);
                        tagText = 'ALLOW';
                      } else if (log.contains('[WARN]')) {
                        txtColor = c.accentAmber;
                        tagBg = c.accentAmber.withValues(alpha: 0.15);
                        tagBorder = c.accentAmber.withValues(alpha: 0.3);
                        tagText = 'WARN';
                      } else if (log.contains('[INFO]')) {
                        txtColor = c.linkAccent;
                      }

                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: index.isEven
                              ? Colors.transparent
                              : c.subCardBg.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Line number
                            SizedBox(
                              width: 38,
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontFamily: 'Cascadia Code',
                                  fontSize: 11,
                                  color: c.textMuted.withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                            // Tag Badge if present
                            if (tagText != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: tagBg,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                      color: tagBorder ?? Colors.transparent),
                                ),
                                child: Text(
                                  tagText,
                                  style: TextStyle(
                                    fontFamily: 'Cascadia Code',
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: txtColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            // Log content
                            Expanded(
                              child: SelectableText(
                                log,
                                style: TextStyle(
                                  fontFamily: 'Cascadia Code',
                                  fontSize: 12,
                                  color: txtColor,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogChip({
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
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color:
              isSelected ? effColor.withValues(alpha: 0.15) : colors.subCardBg,
          borderRadius: BorderRadius.circular(8),
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
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? colors.textPrimary : colors.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? effColor : colors.cardBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 9,
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
