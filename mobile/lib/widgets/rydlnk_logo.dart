import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

/// A more considered take on the rydlnk wordmark. Instead of the
/// bright yellow blob behind "ln", we use a subtle warm-yellow dot
/// as an accent — like a punctuation mark in the name.
class RydlnkLogo extends StatelessWidget {
  const RydlnkLogo({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'rydlnk',
          style: GoogleFonts.dmSerifDisplay(
            fontSize: size,
            color: AppColors.primary,
            letterSpacing: -1.2,
            height: 1.0,
          ),
        ),
        Padding(
          padding: EdgeInsets.only(left: size * 0.12, bottom: size * 0.55),
          child: Container(
            width: size * 0.22,
            height: size * 0.22,
            decoration: const BoxDecoration(
              color: AppColors.markAccent,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
}
