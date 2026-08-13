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
  );
}
