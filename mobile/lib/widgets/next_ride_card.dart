import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class NextRideCard extends StatelessWidget {
  const NextRideCard({
    super.key,
    required this.title,
    required this.from,
    required this.to,
    required this.window,
    required this.driver,
    required this.countdown,
    required this.onTrack,
    required this.onMessage,
  });

  final String title;
  final String from;
  final String to;
  final String window;
  final String driver;
  final String countdown;
  final VoidCallback onTrack;
  final VoidCallback onMessage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.markAccent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.schedule_rounded,
                        size: 12, color: AppColors.accentOrange),
                    const SizedBox(width: 5),
                    Text(
                      'Next ride',
                      style: AppType.caption.copyWith(
                        color: AppColors.accentOrange,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                'in $countdown',
                style: AppType.captionStrong.copyWith(
                  color: AppColors.primary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(title, style: AppType.h3),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.adjust_rounded,
                  size: 13, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$from  →  $to',
                  style: AppType.caption.copyWith(
                      fontSize: 13, color: AppColors.body),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.schedule_rounded,
                  size: 13, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(window,
                  style: AppType.caption.copyWith(
                      fontSize: 13, color: AppColors.body)),
              const SizedBox(width: 14),
              Container(
                width: 3,
                height: 3,
                decoration: const BoxDecoration(
                  color: AppColors.subtle,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 14),
              const Icon(Icons.person_outline_rounded,
                  size: 13, color: AppColors.primary),
              const SizedBox(width: 6),
              Text('with $driver',
                  style: AppType.caption.copyWith(
                      fontSize: 13, color: AppColors.body)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Material(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: onTrack,
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: 13),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.gps_fixed_rounded,
                              size: 16, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            'Track live',
                            style: AppType.button
                                .copyWith(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Material(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: onMessage,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(Icons.chat_bubble_outline_rounded,
                        size: 18, color: AppColors.body),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
