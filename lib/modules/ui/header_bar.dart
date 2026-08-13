// lib/modules/ui/header_bar.dart
// Top header bar: tab title, search box, refresh/theme/language controls.

import 'package:flutter/material.dart';
import '../logic.dart';
import '../i18n.dart';
import '../app_config.dart';
import 'styles.dart';

class HeaderBar extends StatelessWidget {
  final WifiGuardLogic logic;
  final ThemeNotifier themeNotifier;
  final String activeTab;
  final TextEditingController searchController;
  final GlobalKey themeButtonKey;
  final VoidCallback onDataRefreshed;

  const HeaderBar({
    super.key,
    required this.logic,
    required this.themeNotifier,
    required this.activeTab,
    required this.searchController,
    required this.themeButtonKey,
    required this.onDataRefreshed,
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

    String tabTitle = 'Monitor';
    if (activeTab == 'WHITELIST') tabTitle = 'Whitelist Manager';
    if (activeTab == 'CONSOLE') tabTitle = 'Console Terminal';
    if (activeTab == 'HOTSPOT') {
      tabTitle = languageNotifier.language == AppLanguage.vi
          ? 'Cấu hình Hotspot'
          : languageNotifier.language == AppLanguage.zh
              ? '热点配置'
              : 'Mobile Hotspot';
    }
    if (activeTab == 'SETTINGS') tabTitle = 'Global Settings';
    final isTransparent = AppConfig.enableTransparency;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      color:
          isTransparent ? c.bgSecondary.withValues(alpha: 0.1) : c.bgSecondary,
      child: Row(
        children: [
          // Section Title
          Text(
            tabTitle,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: c.textPrimary),
          ),
          const Spacer(),

          // Search Box (only on Monitor & Whitelist tabs)
          if (activeTab == 'MONITOR' || activeTab == 'WHITELIST') ...[
            Container(
              width: 260,
              height: 36,
              margin: const EdgeInsets.only(right: 12),
              child: TextFormField(
                controller: searchController,
                style: TextStyle(color: c.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search MAC, IP...',
                  prefixIcon: Icon(Icons.search, size: 16, color: c.textMuted),
                  suffixIcon: searchController.text.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            searchController.clear();
                            logic.setSearchQuery('');
                          },
                          child:
                              Icon(Icons.clear, size: 16, color: c.textMuted),
                        )
                      : null,
                  filled: true,
                  fillColor: c.bgTertiary.withValues(alpha: 0.4),
                  contentPadding: EdgeInsets.zero,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(
                        color: c.borderDefault.withValues(alpha: 0.15)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(
                        color: c.linkAccent.withValues(alpha: 0.8), width: 1.5),
                  ),
                ),
              ),
            ),
          ],

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
