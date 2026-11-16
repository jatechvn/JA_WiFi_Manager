// lib/modules/ui/settings_tab.dart
// Settings tab: system preferences, whitelist backup, user guide docs.

import 'package:flutter/material.dart';
import '../logic.dart';
import '../i18n.dart';
import 'styles.dart';
import 'bento_widgets.dart';
import 'widgets/power_optimizer_card.dart';
import 'widgets/ota_settings_card.dart';

export 'widgets/power_optimizer_card.dart';
export 'widgets/ota_settings_card.dart';

class SettingsTab extends StatelessWidget {
  final WifiGuardLogic logic;
  final bool startupWithWindows;
  final ValueChanged<bool> onStartupWithWindowsChanged;
  final bool startMinimized;
  final ValueChanged<bool> onStartMinimizedChanged;
  final bool closeToTray;
  final ValueChanged<bool> onCloseToTrayChanged;
  final bool autoStartGuard;
  final ValueChanged<bool> onAutoStartGuardChanged;
  final bool autoStartHotspot;
  final ValueChanged<bool> onAutoStartHotspotChanged;
  final VoidCallback onImportWhitelist;
  final VoidCallback onExportWhitelist;
  final void Function(String message) onSnackbar;

  const SettingsTab({
    super.key,
    required this.logic,
    required this.startupWithWindows,
    required this.onStartupWithWindowsChanged,
    required this.startMinimized,
    required this.onStartMinimizedChanged,
    required this.closeToTray,
    required this.onCloseToTrayChanged,
    required this.autoStartGuard,
    required this.onAutoStartGuardChanged,
    required this.autoStartHotspot,
    required this.onAutoStartHotspotChanged,
    required this.onImportWhitelist,
    required this.onExportWhitelist,
    required this.onSnackbar,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final s = context.strings;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row of System Preferences & Whitelist Backup
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // System Preferences Bento Card
              Expanded(
                flex: 3,
                child: BentoCard(
                  colors: c,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BentoSectionHeader(
                        title: s.settingsSystemTitle,
                        icon: Icons.tune_rounded,
                        colors: c,
                      ),
                      const SizedBox(height: 8),

                      // Auto Check Interval with BentoSegmentedControl.
                      // Label sits above the pills so a narrow card cannot overflow.
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.settingsGuardInterval,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: c.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            s.settingsGuardIntervalDesc,
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
                              items: const [
                                BentoSegmentItem(
                                  value: 5,
                                  label: '5s',
                                  icon: Icons.bolt_rounded,
                                ),
                                BentoSegmentItem(
                                  value: 10,
                                  label: '10s',
                                  icon: Icons.timer_outlined,
                                ),
                                BentoSegmentItem(
                                  value: 30,
                                  label: '30s',
                                  icon: Icons.schedule_rounded,
                                ),
                              ],
                              groupValue: logic.checkIntervalSeconds,
                              onValueChanged: (val) {
                                logic.setCheckInterval(val);
                                onSnackbar(s.settingsIntervalUpdated(val));
                              },
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 12),

                      // Startup with Windows
                      BentoTileSwitch(
                        colors: c,
                        icon: Icons.power_settings_new_rounded,
                        iconColor: c.linkAccent,
                        title: s.settingStartup,
                        subtitle: s.settingStartupDesc,
                        value: startupWithWindows,
                        onChanged: onStartupWithWindowsChanged,
                      ),

                      // Start Minimized
                      BentoTileSwitch(
                        colors: c,
                        icon: Icons.visibility_off_rounded,
                        iconColor: c.linkAccent,
                        title: s.settingStartMinimized,
                        subtitle: s.settingStartMinimizedDesc,
                        value: startMinimized,
                        onChanged: onStartMinimizedChanged,
                      ),

                      // Close to System Tray
                      BentoTileSwitch(
                        colors: c,
                        icon: Icons.close_fullscreen_rounded,
                        iconColor: c.linkAccent,
                        title: s.settingCloseToTray,
                        subtitle: s.settingCloseToTrayDesc,
                        value: closeToTray,
                        onChanged: onCloseToTrayChanged,
                      ),

                      // Auto-start Guard Engine
                      BentoTileSwitch(
                        colors: c,
                        icon: Icons.shield_rounded,
                        iconColor: c.accentEmerald,
                        title: s.settingAutoStartGuard,
                        subtitle: s.settingAutoStartGuardDesc,
                        value: autoStartGuard,
                        onChanged: onAutoStartGuardChanged,
                      ),

                      // Auto-start Mobile Hotspot
                      BentoTileSwitch(
                        colors: c,
                        icon: Icons.wifi_tethering_rounded,
                        iconColor: c.accentCyan,
                        title: s.settingAutoStartHotspot,
                        subtitle: s.settingAutoStartHotspotDesc,
                        value: autoStartHotspot,
                        onChanged: onAutoStartHotspotChanged,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Whitelist Backup Bento Card
              Expanded(
                flex: 2,
                child: BentoCard(
                  colors: c,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BentoSectionHeader(
                        title: s.settingsBackupTitle,
                        icon: Icons.folder_zip_rounded,
                        iconColor: c.accentPurple,
                        colors: c,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        s.settingsBackupDesc,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: c.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          OutlinedButton.icon(
                            onPressed: onImportWhitelist,
                            icon: const Icon(Icons.file_open_rounded, size: 15),
                            label: Text(s.settingsImportFile),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: onExportWhitelist,
                            icon: const Icon(Icons.download_rounded, size: 15),
                            label: Text(s.settingsExportFile),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: c.accentPurple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Power & GPU Optimizer Bento Card
          PowerOptimizerCard(onSnackbar: onSnackbar),
          const SizedBox(height: 10),

          // LAN OTA Update Card
          OtaSettingsCard(onSnackbar: onSnackbar),
          const SizedBox(height: 10),

          // User Guide Bento Card
          BentoCard(
            colors: c,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: DefaultTabController(
              length: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BentoSectionHeader(
                    title: s.settingsGuideTitle,
                    icon: Icons.menu_book_rounded,
                    colors: c,
                  ),
                  const SizedBox(height: 8),
                  TabBar(
                    labelColor: c.linkAccent,
                    unselectedLabelColor: c.textMuted,
                    indicatorColor: c.linkAccent,
                    indicatorSize: TabBarIndicatorSize.label,
                    tabs: [
                      Tab(text: s.guideTabGeneral),
                      Tab(text: s.guideTabSecurity),
                      Tab(text: s.guideTabFAQ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 160,
                    child: TabBarView(
                      children: [
                        TabDocsSection(
                          title: s.guideOverviewTitle,
                          body: s.guideOverviewContent,
                        ),
                        TabDocsSection(
                          title: s.guideSecurityTitle,
                          body: s.guideSecurityContent,
                        ),
                        TabDocsSection(
                          title: s.guideFAQTitle,
                          body: s.guideFAQContent,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
