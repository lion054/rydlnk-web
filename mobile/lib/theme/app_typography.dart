import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Type pairing:
///   • DM Serif Display (italic) — hero moments (the greeting name)
///   • Instrument Serif         — section headers, large numbers
///   • Inter                    — everything else
///
/// Letter-spacing is tuned tight on display sizes, neutral on UI.
class AppType {
  AppType._();

  static TextStyle get hero => GoogleFonts.dmSerifDisplay(
        fontSize: 36,
        height: 1.05,
        fontStyle: FontStyle.italic,
        color: AppColors.ink,
        letterSpacing: -0.5,
      );

  static TextStyle get display => GoogleFonts.instrumentSerif(
        fontSize: 30,
        height: 1.1,
        color: AppColors.ink,
        letterSpacing: -0.4,
      );

  static TextStyle get h1 => GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: AppColors.ink,
        letterSpacing: -0.5,
      );

  static TextStyle get h2 => GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.25,
        color: AppColors.ink,
        letterSpacing: -0.3,
      );

  static TextStyle get h3 => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: AppColors.ink,
        letterSpacing: -0.1,
      );

  static TextStyle get body => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: AppColors.body,
      );

  static TextStyle get bodyStrong => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        height: 1.45,
        color: AppColors.ink,
      );

  static TextStyle get caption => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: AppColors.muted,
      );

  static TextStyle get captionStrong => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: AppColors.body,
      );

  static TextStyle get overline => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        height: 1.4,
        letterSpacing: 1.1,
        color: AppColors.muted,
      );

  static TextStyle get button => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
      );

  static TextStyle get mono => GoogleFonts.jetBrainsMono(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
        letterSpacing: 0.5,
      );
}
