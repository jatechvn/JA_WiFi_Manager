// lib/modules/ui/settings_tab.dart
// Settings tab widgets: static documentation panel.

import 'package:flutter/material.dart';
import 'styles.dart';

class TabDocsSection extends StatelessWidget {
  final String title;
  final String body;

  const TabDocsSection({
    super.key,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: c.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(fontSize: 12, color: c.textSecondary, height: 1.6),
          ),
        ],
      ),
    );
  }
}
