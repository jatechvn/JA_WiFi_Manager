// lib/modules/ui/styles_win11.dart
import 'package:flutter/material.dart';
import 'styles.dart';

class AppColorsWin11 {
  static const dark = AppColors(
    bgPrimary: Color(0x400B0F19), // ~25% opacity for nice Acrylic blend
    bgSecondary: Color(0x55111625), // ~33% opacity
    bgTertiary: Color(0x601A1F2C), // ~38% opacity
    bgCard: Color(0x6A212735), // ~42% opacity
    bgHover: Color(0x1F38BDF8),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFFE2E8F0),
    textMuted: Color(0xFF94A3B8),
    borderDefault: Color(0x2094A3B8),
    borderHighlight: Color(0xFF38BDF8),
    linkAccent: Color(0xFF38BDF8),
    targetAccent: Color(0xFF34D399),
    statusActive: Color(0xFF34D399),
    statusRemoved: Color(0xFFF87171),
    statusChanged: Color(0xFFFBBF24),
    brightness: Brightness.dark,
    cardBg: Color(0x451E293B),
    cardHoverBg: Color(0x60334155),
    subCardBg: Color(0x350F172A),
    subCardBorder: Color(0x20FFFFFF),
    glassHighlight: Color(0x40FFFFFF),
    accentCyan: Color(0xFF38BDF8),
    accentEmerald: Color(0xFF34D399),
    accentAmber: Color(0xFFFBBF24),
    accentRose: Color(0xFFFB7185),
    accentPurple: Color(0xFFC084FC),
  );

  static const light = AppColors(
    bgPrimary: Color(0x40F8FAFC), // ~25% opacity
    bgSecondary: Color(0x55FFFFFF), // ~33% opacity
    bgTertiary: Color(0x60F1F5F9), // ~38% opacity
    bgCard: Color(0x6AFFFFFF), // ~42% opacity
    bgHover: Color(0x190284C7),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF334155),
    textMuted: Color(0xFF64748B),
    borderDefault: Color(0x1864748B),
    borderHighlight: Color(0xFF0284C7),
    linkAccent: Color(0xFF0284C7),
    targetAccent: Color(0xFF0F766E),
    statusActive: Color(0xFF16A34A),
    statusRemoved: Color(0xFFDC2626),
    statusChanged: Color(0xFFD97706),
    brightness: Brightness.light,
    cardBg: Color(0x70FFFFFF),
    cardHoverBg: Color(0x99FFFFFF),
    subCardBg: Color(0x40FFFFFF),
    subCardBorder: Color(0x30CBD5E1),
    glassHighlight: Color(0x80FFFFFF),
    accentCyan: Color(0xFF0284C7),
    accentEmerald: Color(0xFF10B981),
    accentAmber: Color(0xFFF59E0B),
    accentRose: Color(0xFFF43F5E),
    accentPurple: Color(0xFF8B5CF6),
  );
}
