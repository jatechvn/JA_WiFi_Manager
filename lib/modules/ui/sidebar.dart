// lib/modules/ui/sidebar.dart
// Sidebar navigation panel and its nav item widget.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../logic.dart';
import '../constants.dart';
import '../i18n.dart';
import '../app_config.dart';
import 'styles.dart';

class Sidebar extends StatelessWidget {
  final WifiGuardLogic logic;
  final bool isAdmin;
  final String activeTab;
  final ValueChanged<String> onTabSelected;
  final VoidCallback onToggleGuard;

  const Sidebar({
    super.key,
    required this.logic,
    required this.isAdmin,
    required this.activeTab,
    required this.onTabSelected,
    required this.onToggleGuard,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final s = context.strings;
    final clients = logic.connectedClients;
    final wl = logic.whitelist;
    final isGuardActive = logic.isGuardActive;
    final isTransparent = AppConfig.enableTransparency;

    return Container(
      width: 250,
      color:
          isTransparent ? c.bgSecondary.withValues(alpha: 0.4) : c.bgSecondary,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header branding
          Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isGuardActive
                        ? c.statusActive.withValues(alpha: 0.15)
                        : c.textMuted.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: isGuardActive
                        ? [
                            BoxShadow(
                              color: c.statusActive.withValues(alpha: 0.25),
                              blurRadius: 10,
                              spreadRadius: 1,
                            )
                          ]
                        : null,
                  ),
                  child: Icon(
                    Icons.wifi_tethering,
                    color: isGuardActive ? c.statusActive : c.textSecondary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'JA WiFi Guard',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: c.textPrimary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'v$appVersion',
                        style: TextStyle(fontSize: 11, color: c.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Navigation Links
          SidebarNavItem(
            icon: Icons.devices,
            label: s.tabMonitor,
            isSelected: activeTab == 'MONITOR',
            onTap: () => onTabSelected('MONITOR'),
            badgeCount: clients.length,
          ),
          const SizedBox(height: 4),
          SidebarNavItem(
            icon: Icons.verified_user_outlined,
            label: s.tabWhitelist,
            isSelected: activeTab == 'WHITELIST',
            onTap: () => onTabSelected('WHITELIST'),
            badgeCount: wl.length,
          ),
          const SizedBox(height: 4),
          SidebarNavItem(
            icon: Icons.terminal_outlined,
            label: s.tabLogs,
            isSelected: activeTab == 'CONSOLE',
            onTap: () => onTabSelected('CONSOLE'),
            trailing: isGuardActive ? const BlinkingDot(size: 8.0) : null,
          ),
          const SizedBox(height: 4),
          SidebarNavItem(
            icon: Icons.wifi_tethering,
            isSelected: activeTab == 'HOTSPOT',
            onTap: () => onTabSelected('HOTSPOT'),
            label: context.languageNotifier.language == AppLanguage.vi
                ? 'Điểm phát sóng'
                : context.languageNotifier.language == AppLanguage.zh
                    ? '移动热点'
                    : 'Mobile Hotspot',
          ),
          const SizedBox(height: 4),
          SidebarNavItem(
            icon: Icons.settings_outlined,
            label: 'Settings',
            isSelected: activeTab == 'SETTINGS',
            onTap: () => onTabSelected('SETTINGS'),
          ),

          const Spacer(),

          // Guard Activation Card
          GlassCard(
            padding: const EdgeInsets.all(14.0),
            backgroundColor: c.bgCard.withValues(alpha: 0.3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Guard Engine',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: c.textSecondary),
                    ),
                    if (isGuardActive)
                      const BlinkingDot(color: Color(0xFF34D399), size: 7.0)
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isGuardActive
                            ? c.statusActive.withValues(alpha: 0.12)
                            : c.statusRemoved.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isGuardActive
                              ? c.statusActive.withValues(alpha: 0.3)
                              : c.statusRemoved.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        isGuardActive ? 'SECURED' : 'STOPPED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color:
                              isGuardActive ? c.statusActive : c.statusRemoved,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Switch.adaptive(
                      value: isGuardActive,
                      onChanged: (_) => onToggleGuard(),
                      activeThumbColor: c.statusActive,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Live debug timestamp — only shown when launched with -debug
          if (AppConfig.isDebugMode) ...[
            const _DebugClockBadge(),
            const SizedBox(height: 12),
          ],

          // Admin Status Indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isAdmin
                  ? c.statusActive.withValues(alpha: 0.08)
                  : c.statusChanged.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: (isAdmin ? c.statusActive : c.statusChanged)
                    .withValues(alpha: 0.18),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isAdmin ? Icons.shield : Icons.shield_outlined,
                  size: 14,
                  color: isAdmin ? c.statusActive : c.statusChanged,
                ),
                const SizedBox(width: 8),
                Text(
                  isAdmin ? s.labelAdmin : s.labelStandard,
                  style: TextStyle(
                    fontSize: 11,
                    color: isAdmin ? c.statusActive : c.statusChanged,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SidebarNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final int? badgeCount;
  final Widget? trailing;

  const SidebarNavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.badgeCount,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? c.linkAccent.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? c.linkAccent : c.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? c.textPrimary : c.textSecondary,
                  ),
                ),
              ),
              if (trailing != null) ...[
                trailing!,
              ] else if (badgeCount != null && badgeCount! > 0) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? c.linkAccent.withValues(alpha: 0.18)
                        : c.bgTertiary,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: c.borderDefault.withValues(alpha: 0.08)),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? c.linkAccent : c.textMuted,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Standard dart-build-pro debug badge: `DEBUG · v<version> (<build time>)`.
/// Build time is the mtime of data/app.so (the AOT-compiled Dart snapshot
/// bundled by `flutter build windows --release`), not the current time —
/// lets a developer confirm they're running the build they just compiled
/// rather than a stale cached one. Falls back to the exe's own mtime for
/// JIT/`flutter run` debug builds, which have no app.so.
class _DebugClockBadge extends StatelessWidget {
  const _DebugClockBadge();

  DateTime? _resolveBuildTime() {
    try {
      final exeDir = p.dirname(Platform.resolvedExecutable);
      final appSo = File(p.join(exeDir, 'data', 'app.so'));
      if (appSo.existsSync()) {
        return appSo.lastModifiedSync();
      }
      final exe = File(Platform.resolvedExecutable);
      if (exe.existsSync()) {
        return exe.lastModifiedSync();
      }
    } catch (_) {}
    return null;
  }

  String _formatBuildTime(DateTime dt) {
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${pad(dt.month)}-${pad(dt.day)} '
        '${pad(dt.hour)}:${pad(dt.minute)}:${pad(dt.second)}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final buildTime = _resolveBuildTime();
    final buildTimeStr = buildTime != null ? _formatBuildTime(buildTime) : '—';
    final label = 'DEBUG · v$appVersion ($buildTimeStr)';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.statusChanged.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.statusChanged.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bug_report_outlined, size: 12, color: c.statusChanged),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontFamily: 'Cascadia Code',
                fontWeight: FontWeight.w600,
                color: c.statusChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
