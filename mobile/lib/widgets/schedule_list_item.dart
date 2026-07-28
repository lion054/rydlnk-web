import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class ScheduleListItem extends StatelessWidget {
  const ScheduleListItem({
    super.key,
    required this.title,
    required this.window,
    required this.route,
    required this.driver,
    this.highlighted = false,
    this.status,
  });

  final String title;
  final String window;
  final String route;
  final String driver;
  final bool highlighted;
  final String? status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlighted ? AppColors.primary : AppColors.border,
          width: highlighted ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: highlighted
                  ? AppColors.primary
                  : AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.directions_car_filled_rounded,
              color: highlighted ? Colors.white : AppColors.muted,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppType.bodyStrong),
                const SizedBox(height: 2),
                Text(
                  window,
                  style: AppType.captionStrong.copyWith(
                      color: AppColors.primary, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(route, style: AppType.caption.copyWith(fontSize: 12)),
                const SizedBox(height: 2),
                Text(driver, style: AppType.caption.copyWith(fontSize: 12)),
              ],
            ),
          ),
          if (status != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.warningTint,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                status!,
                style: AppType.caption.copyWith(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
