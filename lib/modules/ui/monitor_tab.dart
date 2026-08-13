// lib/modules/ui/monitor_tab.dart
// Monitor tab widgets: stat summary card.

import 'package:flutter/material.dart';
import 'styles.dart';

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
