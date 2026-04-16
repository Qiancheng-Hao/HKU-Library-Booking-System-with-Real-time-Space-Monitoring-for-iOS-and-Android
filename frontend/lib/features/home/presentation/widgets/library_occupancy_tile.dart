import 'package:flutter/material.dart';
import '../../../../core/models/occupancy.dart';
import '../../../../theme/app_theme.dart';

class LibraryOccupancyTile extends StatelessWidget {
  final LibraryOccupancy item;

  const LibraryOccupancyTile({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final occupancyRate = item.clampedOccupancyRate;
    final percentage = occupancyRate.toStringAsFixed(1);
    final isCrowded = occupancyRate > 70;
    final isModerate = occupancyRate > 30 && occupancyRate <= 70;

    final Color statusColor;
    final String statusText;
    if (isCrowded) {
      statusColor = AppColors.statusBusy;
      statusText = 'Busy';
    } else if (isModerate) {
      statusColor = AppColors.statusModerate;
      statusText = 'Moderate';
    } else {
      statusColor = AppColors.statusAvailable;
      statusText = 'Quiet';
    }

    final libraryName = item.displayLibraryName;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 50,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(libraryName, style: tt.titleMedium),
                  Text(
                    item.area,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$percentage%',
                  style: tt.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
                Text(
                  statusText,
                  style: tt.labelSmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
