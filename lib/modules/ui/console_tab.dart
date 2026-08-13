// lib/modules/ui/console_tab.dart
// Console tab: log terminal view with level filter and auto-scroll.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../logic.dart';
import 'styles.dart';

class ConsoleTab extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final c = context.appColors;
    final rawLogs = logic.logLines;

    // Apply log levels filter
    final List<String> logs = [];
    for (final line in rawLogs) {
      if (logLevelFilter == 'BLOCKS' && !line.contains('[BLOCK]')) continue;
      if (logLevelFilter == 'WARNINGS' && !line.contains('[WARN]')) continue;
      logs.add(line);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Controls row
        Row(
          children: [
            // Filter dropdown
            Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: c.bgTertiary,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: c.borderDefault),
              ),
              child: DropdownButton<String>(
                value: logLevelFilter,
                underline: const SizedBox(),
                dropdownColor: c.bgSecondary,
                style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('All Events')),
                  DropdownMenuItem(value: 'BLOCKS', child: Text('Blocks Only')),
                  DropdownMenuItem(
                      value: 'WARNINGS', child: Text('Warnings Only')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    onLogLevelFilterChanged(val);
                  }
                },
              ),
            ),
            const SizedBox(width: 12),

            // Auto scroll checkbox
            Row(
              children: [
                Checkbox(
                  value: autoScrollLogs,
                  onChanged: (val) => onAutoScrollChanged(val ?? true),
                ),
                Text(
                  'Auto Scroll',
                  style: TextStyle(
                      fontSize: 12,
                      color: c.textSecondary,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Spacer(),

            // Copy logs button
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: rawLogs.join('\n')));
                onSnackbar('Logs copied to clipboard');
              },
              icon: const Icon(Icons.copy, size: 14),
              label: const Text('Copy All'),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            const SizedBox(width: 8),

            // Clear logs button
            OutlinedButton.icon(
              onPressed: () async {
                await logic.clearLogs();
                onSnackbar('Log Console Cleared');
              },
              icon: const Icon(Icons.cleaning_services, size: 14),
              label: const Text('Clear'),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Terminal Screen
        Expanded(
          child: GlassCard(
            padding: const EdgeInsets.all(16),
            backgroundColor: c.bgPrimary.withValues(alpha: 0.45),
            borderColor: c.borderDefault.withValues(alpha: 0.15),
            child: ClipRect(
              child: ListView.builder(
                controller: logScrollController,
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final log = logs[index];
                  Color txtColor = c.textSecondary;
                  if (log.contains('[BLOCK]')) {
                    txtColor = c.statusRemoved;
                  } else if (log.contains('[ALLOW]')) {
                    txtColor = c.statusActive;
                  } else if (log.contains('[WARN]')) {
                    txtColor = c.statusChanged;
                  } else if (log.contains('[OK]')) {
                    txtColor = c.statusActive;
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      log,
                      style: TextStyle(
                        fontFamily: 'Cascadia Code',
                        fontSize: 12,
                        color: txtColor,
                        height: 1.4,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
