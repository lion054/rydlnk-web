import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class ImpactCard extends StatelessWidget {
  const ImpactCard({
    super.key,
    required this.rides,
    required this.savedLabel,
    required this.co2Label,
  });

  final int rides;
  final String savedLabel;
  final String co2Label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("This week's impact", style: AppType.h3),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ImpactStat(
                  icon: Icons.check_circle_rounded,
                  iconColor: AppColors.primary,
                  iconTint: AppColors.primaryTint,
                  value: '$rides',
                  valueColor: AppColors.primary,
                  label: 'Rides booked',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ImpactStat(
                  icon: Icons.savings_rounded,
                  iconColor: AppColors.accentBlue,
                  iconTint: AppColors.accentBlueTint,
                  value: savedLabel,
                  valueColor: AppColors.accentBlue,
                  label: 'Money saved',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ImpactStat(
                  icon: Icons.eco_rounded,
                  iconColor: AppColors.accentPurple,
                  iconTint: AppColors.accentPurpleTint,
                  value: co2Label,
                  valueColor: AppColors.accentPurple,
                  label: 'CO₂ saved',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ImpactStat extends StatelessWidget {
  const _ImpactStat({
    required this.icon,
    required this.iconColor,
    required this.iconTint,
    required this.value,
    required this.valueColor,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconTint;
  final String value;
  final Color valueColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconTint,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(height: 10),
        Text(
          value,
          style: AppType.h2.copyWith(color: valueColor, fontSize: 20),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppType.caption.copyWith(fontSize: 11),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
