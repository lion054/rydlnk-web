import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class RideListItem extends StatelessWidget {
  const RideListItem({
    super.key,
    required this.date,
    required this.time,
    required this.from,
    required this.to,
    required this.riders,
    required this.price,
    this.status,
    this.statusColor,
  });

  final String date;
  final String time;
  final String from;
  final String to;
  final int riders;
  final String price;
  final String? status;
  final Color? statusColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(date,
                        style: AppType.bodyStrong.copyWith(fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(time, style: AppType.caption),
                  ],
                ),
              ),
              if (status != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: (statusColor ?? AppColors.warning)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: statusColor ?? AppColors.warning,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        status!,
                        style: AppType.caption.copyWith(
                          color: statusColor ?? AppColors.warning,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _StopLine(
              icon: Icons.my_location_rounded,
              text: from,
              color: AppColors.primary),
          const SizedBox(height: 6),
          _StopLine(
              icon: Icons.place_rounded,
              text: to,
              color: AppColors.markAccent),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.person_outline_rounded,
                  size: 14, color: AppColors.muted),
              const SizedBox(width: 4),
              Text(
                '$riders ${riders == 1 ? "rider" : "riders"}',
                style: AppType.caption,
              ),
              const Spacer(),
              Text(
                price,
                style: AppType.h3.copyWith(
                    color: AppColors.primary, fontSize: 15),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StopLine extends StatelessWidget {
  const _StopLine({required this.icon, required this.text, required this.color});
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: AppType.body.copyWith(fontSize: 14, color: AppColors.ink),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
