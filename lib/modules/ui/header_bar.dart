// lib/modules/ui/header_bar.dart
// Top header bar: tab title, refresh, theme, and language controls.
// Search lives on each tab, not in this bar.

import 'package:flutter/material.dart';
import '../logic.dart';
import '../i18n.dart';
import '../app_config.dart';
import '../services/ota_update_service.dart';
import 'styles.dart';

class HeaderBar extends StatelessWidget {
  final WifiGuardLogic logic;
  final ThemeNotifier themeNotifier;
  final String activeTab;
  final GlobalKey themeButtonKey;
  final VoidCallback onDataRefreshed;
  final UpdatePackageInfo? availableUpdate;
  final VoidCallback? onOpenUpdateDialog;

  const HeaderBar({
    super.key,
    required this.logic,
    required this.themeNotifier,
    required this.activeTab,
    required this.themeButtonKey,
    required this.onDataRefreshed,
    this.availableUpdate,
    this.onOpenUpdateDialog,
  });

  ButtonStyle _iconBtnStyle(AppColors c) => IconButton.styleFrom(
        backgroundColor: c.bgTertiary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: c.borderDefault),
        ),
      );

  String _themeModeLabel(AppStrings s) {
    switch (themeNotifier.mode) {
      case AppThemeMode.dark:
        return s.themeDark;
      case AppThemeMode.light:
        return s.themeLight;
      case AppThemeMode.auto:
        return s.themeAuto;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final s = context.strings;
    final languageNotifier = context.languageNotifier;

    String tabTitle = s.tabTitleMonitor;
    if (activeTab == 'WHITELIST') tabTitle = s.tabTitleWhitelist;
    if (activeTab == 'CONSOLE') tabTitle = s.tabTitleConsole;
    if (activeTab == 'HOTSPOT') tabTitle = s.tabTitleHotspot;
    if (activeTab == 'SETTINGS') tabTitle = s.tabTitleSettings;
    final isTransparent = AppConfig.enableTransparency;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color:
          isTransparent ? c.bgSecondary.withValues(alpha: 0.1) : c.bgSecondary,
      child: Row(
        children: [
          // Section Title
          Text(
            tabTitle,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: c.textPrimary),
          ),
          const Spacer(),

          // Refresh button
          if (activeTab == 'MONITOR' || activeTab == 'WHITELIST') ...[
            Tooltip(
              message: s.tooltipRefresh,
              child: IconButton(
                onPressed: () async {
                  await logic.scanConnectedClients();
                  await logic.readLogLines();
                  onDataRefreshed();
                },
                icon: Icon(Icons.refresh, color: c.textSecondary, size: 18),
                style: _iconBtnStyle(c),
              ),
            ),
            const SizedBox(width: 8),
          ],

          // OTA Update available button
          if (availableUpdate != null) ...[
            Tooltip(
              message:
                  s.otaUpdateAvailable(availableUpdate!.version.displayVersion),
              child: IconButton(
                onPressed: onOpenUpdateDialog,
                icon: const Icon(Icons.system_update_alt_rounded, size: 18),
                color: c.accentEmerald,
                style: IconButton.styleFrom(
                  backgroundColor: c.accentEmerald.withValues(alpha: 0.15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                    side: BorderSide(
                      color: c.accentEmerald.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Theme reveal toggle
          Tooltip(
            key: themeButtonKey,
            message: s.tooltipTheme(_themeModeLabel(s)),
            child: IconButton(
              onPressed: () {
                final themeReveal =
                    context.findAncestorStateOfType<ThemeRevealState>();
                if (themeReveal != null) {
                  themeReveal.triggerReveal(
                    buttonKey: themeButtonKey,
                    onToggle: () => themeNotifier
                        .toggle(MediaQuery.platformBrightnessOf(context)),
                  );
                } else {
                  themeNotifier
                      .toggle(MediaQuery.platformBrightnessOf(context));
                }
              },
              icon: Icon(themeNotifier.modeIcon, color: c.linkAccent, size: 18),
              style: _iconBtnStyle(c),
            ),
          ),
          const SizedBox(width: 8),

          // Language toggle
          Tooltip(
            message:
                '${s.tooltipLanguage}: ${languageNotifier.language.fullLabel}',
            child: InkWell(
              onTap: () => languageNotifier.cycleNext(),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: c.bgTertiary,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: c.borderDefault),
                ),
                child: Row(
                  children: [
                    Icon(Icons.language, size: 14, color: c.linkAccent),
                    const SizedBox(width: 6),
                    Text(
                      languageNotifier.language.shortLabel,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: c.textPrimary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
