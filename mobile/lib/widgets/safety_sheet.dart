import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Rider safety actions for a live ride: call emergency services, or share the
/// trip details with a trusted contact.
class SafetySheet extends StatelessWidget {
  const SafetySheet({super.key, required this.shareText});

  final String shareText;

  /// Local emergency number — set per launch market (999/112 in Zimbabwe,
  /// 911 in the US, etc.).
  static const String emergencyNumber = '999';

  static void show(BuildContext context, {required String shareText}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => SafetySheet(shareText: shareText),
    );
  }

  Future<void> _call() async {
    final uri = Uri(scheme: 'tel', path: emergencyNumber);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _share() async {
    await Share.share(shareText, subject: 'My Rydlnk trip');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, 28 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Text('Safety', style: AppType.h3),
          const SizedBox(height: 6),
          Text('Get help fast, or let someone follow your ride.',
              style: AppType.body),
          const SizedBox(height: 20),
          _Action(
            icon: Icons.emergency_share_rounded,
            iconColor: AppColors.danger,
            iconBg: AppColors.dangerTint,
            title: 'Call emergency ($emergencyNumber)',
            subtitle: 'Dial local emergency services now',
            onTap: _call,
          ),
          const SizedBox(height: 10),
          _Action(
            icon: Icons.ios_share_rounded,
            iconColor: AppColors.primary,
            iconBg: AppColors.primaryTint,
            title: 'Share my trip',
            subtitle: 'Send your ride details to a trusted contact',
            onTap: _share,
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                    color: iconBg, borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppType.bodyStrong),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppType.caption),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 20, color: AppColors.subtle),
            ],
          ),
        ),
      ),
    );
  }
}
