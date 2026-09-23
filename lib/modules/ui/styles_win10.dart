// lib/modules/ui/styles_win10.dart
import 'package:flutter/material.dart';
import 'styles.dart';

class AppColorsWin10 {
  static const dark = AppColors(
    bgPrimary: Color(0xB20B0F19), // ~70% opacity
    bgSecondary: Color(0xCC111625), // ~80% opacity
    bgTertiary: Color(0xD91A1F2C), // ~85% opacity
    bgCard: Color(0xD9212735), // ~85% opacity
    bgHover: Color(0x1F38BDF8),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFFE2E8F0),
    textMuted: Color(0xFF94A3B8),
    borderDefault: Color(0x2B94A3B8),
    borderHighlight: Color(0xFF38BDF8),
    linkAccent: Color(0xFF38BDF8),
    targetAccent: Color(0xFF34D399),
    statusActive: Color(0xFF34D399),
    statusRemoved: Color(0xFFF87171),
    statusChanged: Color(0xFFFBBF24),
    brightness: Brightness.dark,
    cardBg: Color(0x381E293B),
    cardHoverBg: Color(0x55334155),
    subCardBg: Color(0x2E0F172A),
    subCardBorder: Color(0x26FFFFFF),
    glassHighlight: Color(0x4DFFFFFF),
    accentCyan: Color(0xFF38BDF8),
    accentEmerald: Color(0xFF34D399),
    accentAmber: Color(0xFFFBBF24),
    accentRose: Color(0xFFFB7185),
    accentPurple: Color(0xFFC084FC),
  );

  static const light = AppColors(
    bgPrimary: Color(0xB2F8FAFC), // ~70% opacity
    bgSecondary: Color(0xCCFFFFFF), // ~80% opacity
    bgTertiary: Color(0xD9F1F5F9), // ~85% opacity
    bgCard: Color(0xD9FFFFFF), // ~85% opacity
    bgHover: Color(0x190284C7),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF334155),
    textMuted: Color(0xFF64748B),
    borderDefault: Color(0x2664748B),
    borderHighlight: Color(0xFF0284C7),
    linkAccent: Color(0xFF0284C7),
    targetAccent: Color(0xFF0F766E),
    statusActive: Color(0xFF16A34A),
    statusRemoved: Color(0xFFDC2626),
    statusChanged: Color(0xFFD97706),
    brightness: Brightness.light,
    cardBg: Color(0x66FFFFFF), // ~40% white with blur for high legibility
    cardHoverBg: Color(0x99FFFFFF),
    subCardBg: Color(0x38FFFFFF),
    subCardBorder: Color(0x3364748B),
    glassHighlight: Color(0x80FFFFFF),
    accentCyan: Color(0xFF00D2FF),
    accentEmerald: Color(0xFF10B981),
    accentAmber: Color(0xFFF59E0B),
    accentRose: Color(0xFFF43F5E),
    accentPurple: Color(0xFF8B5CF6),
  );
}
