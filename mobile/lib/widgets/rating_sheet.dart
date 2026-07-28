import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Collects a 1–5 star rating (+ optional comment). Returns null if dismissed.
class RatingResult {
  RatingResult(this.stars, this.comment);
  final int stars;
  final String? comment;
}

class RatingSheet extends StatefulWidget {
  const RatingSheet({super.key});

  static Future<RatingResult?> show(BuildContext context) {
    return showModalBottomSheet<RatingResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: const RatingSheet(),
      ),
    );
  }

  @override
  State<RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends State<RatingSheet> {
  int _stars = 0;
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
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
          Text('Rate your driver', style: AppType.h3),
          const SizedBox(height: 4),
          Text('How was the trip?', style: AppType.caption),
          const SizedBox(height: 18),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 1; i <= 5; i++)
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _stars = i);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        i <= _stars
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 40,
                        color: i <= _stars
                            ? AppColors.markAccent
                            : AppColors.subtle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              controller: _comment,
              minLines: 2,
              maxLines: 4,
              style: AppType.body,
              decoration: InputDecoration(
                hintText: 'Add a note (optional)',
                hintStyle: AppType.body.copyWith(color: AppColors.subtle),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Material(
            color: _stars == 0 ? AppColors.borderStrong : AppColors.primary,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: _stars == 0
                  ? null
                  : () => Navigator.pop(
                      context,
                      RatingResult(
                          _stars,
                          _comment.text.trim().isEmpty
                              ? null
                              : _comment.text.trim())),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                alignment: Alignment.center,
                child: Text('Submit rating',
                    style: AppType.button.copyWith(color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
