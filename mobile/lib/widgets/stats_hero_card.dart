import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// The big green gradient card on the dashboard with the greeting
/// and the week's stats (rides / savings / CO₂ saved).
class StatsHeroCard extends StatelessWidget {
  const StatsHeroCard({
    super.key,
    required this.greeting,
    required this.name,
    required this.subtitle,
    required this.rides,
    required this.savings,
    required this.co2,
  });

  final String greeting;
  final String name;
  final String subtitle;
  final int rides;
  final String savings;
  final String co2;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.waving_hand_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$greeting, $name',
                      style: AppType.h2.copyWith(
                        color: Colors.white,
                        fontSize: 19,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppType.body.copyWith(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  icon: Icons.directions_car_rounded,
                  value: '$rides',
                  label: 'Rides this week',
                ),
              ),
              const _StatDivider(),
              Expanded(
                child: _Stat(
                  icon: Icons.savings_outlined,
                  value: savings,
                  label: 'Weekly savings',
                ),
              ),
              const _StatDivider(),
              Expanded(
                child: _Stat(
                  icon: Icons.eco_outlined,
                  value: co2,
                  label: 'CO\u2082 saved',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 18),
        const SizedBox(height: 6),
        Text(
          value,
          style: AppType.h3.copyWith(color: Colors.white, fontSize: 17),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppType.caption.copyWith(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 11,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: Colors.white.withValues(alpha: 0.18),
    );
  }
}
