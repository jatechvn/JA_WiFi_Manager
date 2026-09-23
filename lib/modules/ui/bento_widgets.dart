// lib/modules/ui/bento_widgets.dart
// Reusable Bento Glassmorphic components inspired by JA_Mini_Showcase:
// - BentoCard: High-performance frosted card with top highlight and hover glow
// - PillBadge: Status badge with optional glowing LED indicator
// - FilterSearchDock: Integrated search bar with instant filter chips and view toggler
// - DeviceTypeHelper: Intelligent device categorization & icon deduction

import 'package:flutter/material.dart';
import '../app_config.dart';
import '../i18n.dart';
import 'styles.dart';

/// Bento Grid Card with top-edge glass highlight and smooth hover effect.
class BentoCard extends StatelessWidget {
  final AppColors colors;
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool isFeatured;
  final Color? customBg;
  final Color? customBorder;
  final bool showTopHighlight;

  const BentoCard({
    super.key,
    required this.colors,
    required this.child,
    this.borderRadius = 16.0,
    this.padding = const EdgeInsets.all(16.0),
    this.onTap,
    this.isFeatured = false,
    this.customBg,
    this.customBorder,
    this.showTopHighlight = true,
  });

  @override
  Widget build(BuildContext context) {
    final isTransparent = AppConfig.enableTransparency;
    final effectiveBg = customBg ??
        (isTransparent ? colors.cardBg : colors.cardBg.withValues(alpha: 1.0));

    final effectiveBorder = customBorder ??
        (isFeatured
            ? colors.accentCyan.withValues(alpha: 0.4)
            : colors.borderDefault);

    Widget inner = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        hoverColor: colors.cardHoverBg.withValues(alpha: 0.18),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: effectiveBorder,
          width: isFeatured ? 1.2 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          if (isFeatured)
            BoxShadow(
              color: colors.linkAccent.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      foregroundDecoration: showTopHighlight
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border(
                top: BorderSide(
                  color: isFeatured
                      ? colors.accentCyan.withValues(alpha: 0.55)
                      : colors.glassHighlight,
                  width: 1,
                ),
              ),
            )
          : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: RepaintBoundary(child: inner),
      ),
    );
  }
}

/// Small rounded-pill badge, optionally with a glowing status LED dot.
class PillBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;
  final Color border;
  final bool showDot;
  final IconData? icon;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const PillBadge({
    super.key,
    required this.label,
    required this.color,
    required this.bg,
    required this.border,
    this.showDot = false,
    this.icon,
    this.fontSize = 11,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.6),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
          ],
          if (icon != null) ...[
            Icon(icon, size: fontSize + 1, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// A search field + filter chips and view switcher dock
class FilterSearchDock extends StatelessWidget {
  final AppColors colors;
  final TextEditingController searchController;
  final String searchHint;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final List<FilterChipData> filters;
  final String selectedFilter;
  final ValueChanged<String> onFilterSelected;
  final bool isCardView;
  final ValueChanged<bool> onViewModeChanged;

  const FilterSearchDock({
    super.key,
    required this.colors,
    required this.searchController,
    required this.searchHint,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.filters,
    required this.selectedFilter,
    required this.onFilterSelected,
    required this.isCardView,
    required this.onViewModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    return BentoCard(
      colors: colors,
      borderRadius: 12,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isSingleRow = constraints.maxWidth >= 550;

          final searchWidget = Row(
            children: [
              Icon(Icons.search_rounded, size: 16, color: colors.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: searchController,
                  onChanged: onSearchChanged,
                  style: TextStyle(color: colors.textPrimary, fontSize: 12.5),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                    hintText: searchHint,
                    hintStyle: TextStyle(color: colors.textMuted, fontSize: 12),
                  ),
                ),
              ),
              if (searchController.text.isNotEmpty)
                IconButton(
                  icon: Icon(Icons.close_rounded,
                      size: 14, color: colors.textMuted),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 24, minHeight: 24),
                  tooltip: s.tooltipClearSearch,
                  onPressed: onClearSearch,
                ),
            ],
          );

          final viewModeWidget = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ViewModeButton(
                icon: Icons.grid_view_rounded,
                tooltip: s.tooltipCardView,
                isSelected: isCardView,
                colors: colors,
                onTap: () => onViewModeChanged(true),
              ),
              const SizedBox(width: 4),
              _ViewModeButton(
                icon: Icons.table_rows_rounded,
                tooltip: s.tooltipTableView,
                isSelected: !isCardView,
                colors: colors,
                onTap: () => onViewModeChanged(false),
              ),
            ],
          );

          final filterPillsWidget = SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: filters.map((f) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _FilterPill(
                    data: f,
                    isSelected: f.key == selectedFilter,
                    colors: colors,
                    onTap: () => onFilterSelected(f.key),
                  ),
                );
              }).toList(),
            ),
          );

          if (isSingleRow) {
            return Row(
              children: [
                SizedBox(
                  width: 200,
                  child: searchWidget,
                ),
                Container(
                  height: 18,
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  color: colors.subCardBorder,
                ),
                Expanded(
                  child: filterPillsWidget,
                ),
                const SizedBox(width: 8),
                viewModeWidget,
              ],
            );
          }

          // Fallback multi-row for narrow width
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child: searchWidget),
                  const SizedBox(width: 8),
                  viewModeWidget,
                ],
              ),
              if (filters.isNotEmpty) ...[
                const SizedBox(height: 6),
                Divider(color: colors.subCardBorder, height: 1),
                const SizedBox(height: 6),
                filterPillsWidget,
              ],
            ],
          );
        },
      ),
    );
  }
}

class FilterChipData {
  final String key;
  final String label;
  final int count;
  final Color? activeColor;
  final IconData? icon;

  const FilterChipData({
    required this.key,
    required this.label,
    required this.count,
    this.activeColor,
    this.icon,
  });
}

class _FilterPill extends StatelessWidget {
  final FilterChipData data;
  final bool isSelected;
  final AppColors colors;
  final VoidCallback onTap;

  const _FilterPill({
    required this.data,
    required this.isSelected,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeCol = data.activeColor ?? colors.linkAccent;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color:
              isSelected ? activeCol.withValues(alpha: 0.18) : colors.subCardBg,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isSelected
                ? activeCol.withValues(alpha: 0.6)
                : colors.subCardBorder,
            width: isSelected ? 1.2 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (data.icon != null) ...[
              Icon(
                data.icon,
                size: 13,
                color: isSelected ? activeCol : colors.textMuted,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              data.label,
              style: TextStyle(
                color: isSelected ? activeCol : colors.textSecondary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? activeCol.withValues(alpha: 0.25)
                    : colors.textMuted.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${data.count}',
                style: TextStyle(
                  color: isSelected ? activeCol : colors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cascadia Code',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewModeButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isSelected;
  final AppColors colors;
  final VoidCallback onTap;

  const _ViewModeButton({
    required this.icon,
    required this.tooltip,
    required this.isSelected,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color:
                isSelected ? colors.linkAccent.withValues(alpha: 0.15) : null,
            borderRadius: BorderRadius.circular(6),
            border: isSelected
                ? Border.all(color: colors.linkAccent.withValues(alpha: 0.35))
                : null,
          ),
          child: Icon(
            icon,
            size: 17,
            color: isSelected ? colors.linkAccent : colors.textMuted,
          ),
        ),
      ),
    );
  }
}

/// Helper to analyze hostnames and vendors to classify device types and clean display names.
class DeviceTypeHelper {
  /// Deduce appropriate icon for a device based on its name, hostname, or IP.
  static IconData getDeviceIcon(String rawName, String ip) {
    final lower = rawName.toLowerCase();

    if (lower.contains('iphone') ||
        lower.contains('galaxy') ||
        lower.contains('samsung') ||
        lower.contains('pixel') ||
        lower.contains('xiaomi') ||
        lower.contains('redmi') ||
        lower.contains('oppo') ||
        lower.contains('vivo') ||
        lower.contains('android') ||
        lower.contains('phone') ||
        lower.contains('mobile')) {
      return Icons.smartphone_rounded;
    }

    if (lower.contains('ipad') ||
        lower.contains('tablet') ||
        lower.contains('tab')) {
      return Icons.tablet_mac_rounded;
    }

    if (lower.contains('macbook') ||
        lower.contains('laptop') ||
        lower.contains('thinkpad') ||
        lower.contains('dell') ||
        lower.contains('hp') ||
        lower.contains('asus') ||
        lower.contains('lenovo') ||
        lower.contains('acer')) {
      return Icons.laptop_windows_rounded;
    }

    if (lower.contains('desktop') ||
        lower.contains('workstation') ||
        lower.contains('pc') ||
        lower.contains('win-') ||
        lower.contains('host')) {
      return Icons.computer_rounded;
    }

    if (lower.contains('server') ||
        lower.contains('nas') ||
        lower.contains('pi') ||
        lower.contains('iot') ||
        lower.contains('sensor') ||
        lower.contains('camera') ||
        lower.contains('esp')) {
      return Icons.memory_rounded;
    }

    if (lower.contains('router') ||
        lower.contains('ap') ||
        lower.contains('gateway') ||
        lower.contains('switch')) {
      return Icons.router_rounded;
    }

    return Icons.devices_rounded;
  }

  /// Format mDNS hostnames cleanly (e.g. "DESKTOP-7V2VRAR.mshome.net" -> "DESKTOP-7V2VRAR")
  static String cleanHostname(String raw) {
    if (raw.isEmpty) return '';
    var clean = raw;
    if (clean.endsWith('.mshome.net')) {
      clean = clean.substring(0, clean.length - 11);
    } else if (clean.endsWith('.local')) {
      clean = clean.substring(0, clean.length - 6);
    } else if (clean.endsWith('.lan')) {
      clean = clean.substring(0, clean.length - 4);
    }
    return clean.trim();
  }

  /// Get the best user-facing display name
  static String getDisplayName(String nickname, String mac) {
    if (nickname.isNotEmpty) {
      return cleanHostname(nickname);
    }
    final cleanMac = mac.replaceAll(':', '').replaceAll('-', '').toUpperCase();
    final suffix = cleanMac.length >= 4
        ? cleanMac.substring(cleanMac.length - 4)
        : cleanMac;
    return 'Thiết bị #${suffix.isNotEmpty ? suffix : "WiFi"}';
  }
}

/// Bento Section Header with colored icon pill
class BentoSectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final AppColors colors;
  final Color? iconColor;
  final Color? iconBg;
  final Widget? trailing;

  const BentoSectionHeader({
    super.key,
    required this.title,
    required this.icon,
    required this.colors,
    this.iconColor,
    this.iconBg,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = iconColor ?? colors.linkAccent;
    final effectiveIconBg =
        iconBg ?? effectiveIconColor.withValues(alpha: 0.12);

    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: effectiveIconBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: effectiveIconColor.withValues(alpha: 0.25),
            ),
          ),
          child: Icon(icon, size: 16, color: effectiveIconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
              letterSpacing: 0.2,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Bento Switch Tile with leading icon container
class BentoTileSwitch extends StatelessWidget {
  final AppColors colors;
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const BentoTileSwitch({
    super.key,
    required this.colors,
    required this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final effColor = iconColor ?? colors.linkAccent;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: effColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: effColor.withValues(alpha: 0.2),
              ),
            ),
            child: Icon(icon, size: 16, color: effColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: colors.textMuted,
                      height: 1.25,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Transform.scale(
            scale: 0.85,
            child: Switch(
              value: value,
              activeThumbColor: colors.statusActive,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bento Segmented Option model
class BentoSegmentItem<T> {
  final T value;
  final String label;
  final IconData? icon;

  const BentoSegmentItem({
    required this.value,
    required this.label,
    this.icon,
  });
}

/// Bento Segmented Pill Controller
class BentoSegmentedControl<T> extends StatelessWidget {
  final AppColors colors;
  final List<BentoSegmentItem<T>> items;
  final T groupValue;
  final ValueChanged<T> onValueChanged;

  const BentoSegmentedControl({
    super.key,
    required this.colors,
    required this.items,
    required this.groupValue,
    required this.onValueChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.subCardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.borderDefault),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: items.map((item) {
          final isSelected = item.value == groupValue;
          return InkWell(
            onTap: () => onValueChanged(item.value),
            borderRadius: BorderRadius.circular(7),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? colors.linkAccent.withValues(alpha: 0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: isSelected
                      ? colors.linkAccent.withValues(alpha: 0.5)
                      : Colors.transparent,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (item.icon != null) ...[
                    Icon(
                      item.icon,
                      size: 14,
                      color: isSelected ? colors.linkAccent : colors.textMuted,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected
                          ? colors.textPrimary
                          : colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
