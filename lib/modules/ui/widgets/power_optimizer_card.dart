// lib/modules/ui/widgets/power_optimizer_card.dart
// Bento Card for Power & GPU Optimization (Idle Sleep Mode & Timeout)

import 'package:flutter/material.dart';
import '../../i18n.dart';
import '../../services/app_power_manager.dart';
import '../bento_widgets.dart';
import '../styles.dart';

/// Bento Card for Power & GPU Optimization (Idle Sleep Mode & Timeout)
class PowerOptimizerCard extends StatefulWidget {
  final void Function(String message) onSnackbar;

  const PowerOptimizerCard({super.key, required this.onSnackbar});

  @override
  State<PowerOptimizerCard> createState() => _PowerOptimizerCardState();
}

class _PowerOptimizerCardState extends State<PowerOptimizerCard> {
  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final s = context.strings;
    final powerManager = AppPowerManager.instance;

    return BentoCard(
      colors: c,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BentoSectionHeader(
            title: s.settingsPowerOptimizerTitle,
            icon: Icons.bolt_rounded,
            iconColor: c.accentAmber,
            colors: c,
          ),
          const SizedBox(height: 8),

          // Enable Idle Sleep Mode Switch
          BentoTileSwitch(
            colors: c,
            icon: Icons.bedtime_rounded,
            iconColor: c.accentAmber,
            title: s.settingEnableIdleSleep,
            subtitle: s.settingEnableIdleSleepDesc,
            value: powerManager.enableIdleSleep,
            onChanged: (val) {
              setState(() {
                powerManager.setEnableIdleSleep(val);
              });
              widget.onSnackbar(
                val
                    ? '${s.settingEnableIdleSleep}: ON'
                    : '${s.settingEnableIdleSleep}: OFF',
              );
            },
          ),
          const Divider(height: 12),

          // Idle Timeout Duration Selector
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.settingIdleTimeout,
                style: TextStyle(
                  fontSize: 12.5,
                  color: c.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                s.settingIdleTimeoutDesc,
                style: TextStyle(
                  fontSize: 10.5,
                  color: c.textMuted,
                ),
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: BentoSegmentedControl<int>(
                  colors: c,
                  items: [
                    BentoSegmentItem(
                      value: 12,
                      label: s.idleTimeout12s,
                      icon: Icons.timer_outlined,
                    ),
                    BentoSegmentItem(
                      value: 30,
                      label: s.idleTimeout30s,
                      icon: Icons.schedule_rounded,
                    ),
                    BentoSegmentItem(
                      value: 60,
                      label: s.idleTimeout60s,
                      icon: Icons.hourglass_bottom_rounded,
                    ),
                  ],
                  groupValue: powerManager.idleTimeoutSeconds,
                  onValueChanged: (val) {
                    setState(() {
                      powerManager.setIdleTimeoutSeconds(val);
                    });
                    widget.onSnackbar(s.settingsPowerUpdated(val));
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
