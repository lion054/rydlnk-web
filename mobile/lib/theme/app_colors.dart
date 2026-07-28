import 'package:flutter/material.dart';

/// rydlnk colour system.
///
/// Replaces the original's saturated lime green with a deeper, more
/// considered emerald. Backgrounds are warm off-white (slight yellow
/// undertone) so the whole UI feels like paper rather than a screen.
class AppColors {
  AppColors._();

  // Primary — deep emerald
  static const Color primary = Color(0xFF0B5D3B);
  static const Color primaryDark = Color(0xFF084229);
  static const Color primaryTint = Color(0xFFE8F3EC);
  static const Color primarySurface = Color(0xFFF3F9F4);

  // Accent — soft mint for inline highlights
  static const Color mint = Color(0xFFD4F0D9);
  static const Color mintInk = Color(0xFF0D7A4A);

  // Neutrals — warm-toned so they pair with the off-white bg
  static const Color background = Color(0xFFFAFAF6);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color elevatedSurface = Color(0xFFFDFCF8);

  // Text — tuned for WCAG AA legibility on the warm off-white ground.
  static const Color ink = Color(0xFF14181A);
  static const Color body = Color(0xFF434B51);
  static const Color muted = Color(0xFF6C737A); // was #8B939A (raised contrast)
  static const Color subtle = Color(0xFF9AA1A7); // was #B8BEC3

  // Lines
  static const Color border = Color(0xFFECEAE4);
  static const Color borderStrong = Color(0xFFDDD9CF);
  static const Color divider = Color(0xFFF1EFE9);

  // States
  static const Color warning = Color(0xFFC8851F);
  static const Color warningTint = Color(0xFFFBF1E0);
  static const Color danger = Color(0xFFB0413E);
  static const Color dangerTint = Color(0xFFF7E5E4);

  // Brand mark accent (replaces the bright yellow circle)
  static const Color markAccent = Color(0xFFE6C547);

  // Quick-action / category accents (muted, paired with their tint)
  static const Color accentBlue = Color(0xFF2D6FBA);
  static const Color accentBlueTint = Color(0xFFE4EEF9);
  static const Color accentPurple = Color(0xFF6B4F9E);
  static const Color accentPurpleTint = Color(0xFFEEE8F7);
  static const Color accentOrange = Color(0xFFC76A1A);
  static const Color accentOrangeTint = Color(0xFFFBECDE);
  static const Color accentBlush = Color(0xFFB5485F);
  static const Color accentBlushTint = Color(0xFFF7E4E9);
}
