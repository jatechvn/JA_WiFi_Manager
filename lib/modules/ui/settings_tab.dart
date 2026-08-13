// lib/modules/ui/settings_tab.dart
// Settings tab: system preferences, whitelist backup, user guide docs.

import 'package:flutter/material.dart';
import '../logic.dart';
import '../i18n.dart';
import 'styles.dart';

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
          // Row of Transparency & Interval Card
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // System Preferences
              Expanded(
                child: GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StyledWidgets.sectionHeader(s.settingsSystemTitle, c,
                          icon: Icons.tune),
                      const SizedBox(height: 12),

                      // Auto Check Interval
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(Icons.timer_outlined,
                                    size: 20, color: c.linkAccent),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(s.settingsGuardInterval,
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: c.textPrimary,
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 2),
                                      Text(s.settingsGuardIntervalDesc,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: c.textMuted)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            height: 32,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: c.bgTertiary,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: c.borderDefault),
                            ),
                            child: DropdownButton<int>(
                              value: logic.checkIntervalSeconds,
                              underline: const SizedBox(),
                              dropdownColor: c.bgSecondary,
                              style: TextStyle(
                                  color: c.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold),
                              items: [
                                DropdownMenuItem(
                                    value: 5, child: Text(s.settingsSec5)),
                                DropdownMenuItem(
                                    value: 10, child: Text(s.settingsSec10)),
                                DropdownMenuItem(
                                    value: 30, child: Text(s.settingsSec30)),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  logic.setCheckInterval(val);
                                  onSnackbar(
                                      'Interval updated to $val seconds');
                                }
                              },
                            ),
                          ),
                        ],
                      ),

                      // Startup with Windows
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(Icons.power_settings_new_outlined,
                                    size: 20, color: c.linkAccent),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(s.settingStartup,
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: c.textPrimary,
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 2),
                                      Text(s.settingStartupDesc,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: c.textMuted)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: startupWithWindows,
                            activeThumbColor: c.statusActive,
                            onChanged: onStartupWithWindowsChanged,
                          ),
                        ],
                      ),

                      // Start Minimized to Tray
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(Icons.visibility_off_outlined,
                                    size: 20, color: c.linkAccent),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(s.settingStartMinimized,
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: c.textPrimary,
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 2),
                                      Text(s.settingStartMinimizedDesc,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: c.textMuted)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: startMinimized,
                            activeThumbColor: c.statusActive,
                            onChanged: onStartMinimizedChanged,
                          ),
                        ],
                      ),

                      // Close to System Tray
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(Icons.close_fullscreen_outlined,
                                    size: 20, color: c.linkAccent),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(s.settingCloseToTray,
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: c.textPrimary,
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 2),
                                      Text(s.settingCloseToTrayDesc,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: c.textMuted)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: closeToTray,
                            activeThumbColor: c.statusActive,
                            onChanged: onCloseToTrayChanged,
                          ),
                        ],
                      ),

                      // Auto-start Guard on Launch
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(Icons.shield_outlined,
                                    size: 20, color: c.linkAccent),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(s.settingAutoStartGuard,
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: c.textPrimary,
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 2),
                                      Text(s.settingAutoStartGuardDesc,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: c.textMuted)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: autoStartGuard,
                            activeThumbColor: c.statusActive,
                            onChanged: onAutoStartGuardChanged,
                          ),
                        ],
                      ),

                      // Auto-start Hotspot on Launch
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(Icons.wifi_tethering_outlined,
                                    size: 20, color: c.linkAccent),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(s.settingAutoStartHotspot,
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: c.textPrimary,
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 2),
                                      Text(s.settingAutoStartHotspotDesc,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: c.textMuted)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: autoStartHotspot,
                            activeThumbColor: c.statusActive,
                            onChanged: onAutoStartHotspotChanged,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Whitelist Backup Services
              Expanded(
                child: GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StyledWidgets.sectionHeader(
                          'Whitelist Data Management', c,
                          icon: Icons.folder_zip_outlined),
                      const SizedBox(height: 16),
                      Text(
                        'Import or export your whitelisted MAC addresses database to back up your configurations.',
                        style: TextStyle(
                            fontSize: 12, color: c.textSecondary, height: 1.5),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: onImportWhitelist,
                              icon: const Icon(Icons.file_open_outlined,
                                  size: 16),
                              label: const Text('Import Whitelist'),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: onExportWhitelist,
                              icon: const Icon(Icons.download, size: 16),
                              label: const Text('Export Whitelist'),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
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
          const SizedBox(height: 20),

          // User Guide Card
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: DefaultTabController(
              length: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StyledWidgets.sectionHeader('System Documentation & Guide', c,
                      icon: Icons.info_outline),
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
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 210,
                    child: TabBarView(
                      children: [
                        TabDocsSection(
                            title: s.guideOverviewTitle,
                            body: s.guideOverviewContent),
                        TabDocsSection(
                            title: s.guideSecurityTitle,
                            body: s.guideSecurityContent),
                        TabDocsSection(
                            title: s.guideFAQTitle, body: s.guideFAQContent),
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
