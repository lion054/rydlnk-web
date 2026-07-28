import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class WizardStepper extends StatelessWidget {
  const WizardStepper({
    super.key,
    required this.total,
    required this.current,
  });

  /// 0-indexed current step.
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total * 2 - 1, (i) {
        if (i.isOdd) {
          final lineIndex = (i - 1) ~/ 2;
          final done = lineIndex < current;
          return Expanded(
            child: Container(
              height: 1.5,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              color: done ? AppColors.primary : AppColors.border,
            ),
          );
        }
        final stepIndex = i ~/ 2;
        final isDone = stepIndex < current;
        final isCurrent = stepIndex == current;
        return _StepDot(done: isDone, current: isCurrent);
      }),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.done, required this.current});
  final bool done;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final filled = done || current;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: filled ? AppColors.primary : AppColors.surface,
        shape: BoxShape.circle,
        border: Border.all(
          color: filled ? AppColors.primary : AppColors.border,
          width: 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: done
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
          : current
              ? Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                )
              : null,
    );
  }
}
