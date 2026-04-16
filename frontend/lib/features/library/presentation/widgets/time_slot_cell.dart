import 'package:flutter/material.dart';
import '../../../../core/models/time_slot.dart';
import '../../../../theme/app_theme.dart';

class TimeSlotCell extends StatelessWidget {
  final TimeSlot slot;
  final bool isSelected;
  final VoidCallback? onTap;

  const TimeSlotCell({
    super.key,
    required this.slot,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final isAvailable = slot.isAvailable;
    final startTime = slot.shortStartTime;
    final endTime = slot.shortEndTime;

    final Color bgColor;
    final Color textColor;
    if (isSelected) {
      bgColor = cs.primary;
      textColor = cs.onPrimary;
    } else if (isAvailable) {
      bgColor = AppColors.statusAvailable.withValues(alpha: 0.28);
      textColor = AppColors.statusAvailable;
    } else {
      bgColor = cs.surfaceContainerHighest.withValues(alpha: 0.5);
      textColor = cs.onSurfaceVariant;
    }

    final Border border;
    if (isSelected) {
      border = Border.all(color: cs.primary, width: 2);
    } else if (isAvailable) {
      border = Border.all(
        color: AppColors.statusAvailable.withValues(alpha: 0.55),
        width: 1,
      );
    } else {
      border = Border.all(color: cs.outlineVariant, width: 1);
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: border,
        ),
        alignment: Alignment.center,
        child: Text(
          '$startTime\n$endTime',
          textAlign: TextAlign.center,
          style: tt.labelSmall?.copyWith(
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
