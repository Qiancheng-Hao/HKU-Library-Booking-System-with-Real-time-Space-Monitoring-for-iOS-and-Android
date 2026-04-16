import 'package:flutter/material.dart';
import '../../../../core/models/occupancy.dart';
import '../../../../theme/app_theme.dart';

class BestSpotCard extends StatelessWidget {
  final LibraryOccupancy? recommendation;
  final bool isLoading;
  final String? errorMessage;
  final String strategy;
  final void Function(String) onStrategyChanged;

  const BestSpotCard({
    super.key,
    required this.recommendation,
    required this.isLoading,
    this.errorMessage,
    required this.strategy,
    required this.onStrategyChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final Widget content;

    if (isLoading && recommendation == null) {
      content = const Center(child: CircularProgressIndicator());
    } else if (recommendation == null) {
      content = Row(
        children: [
          Icon(Icons.error_outline, size: 40, color: cs.onSurfaceVariant),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No Recommendation',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  errorMessage ?? 'Check open hours or try again later.',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      final data = recommendation!;
      final libraryName = data.displayLibraryName;
      final area = data.area;
      final occupancyRate = data.clampedOccupancyRate;
      final percentage = occupancyRate.toStringAsFixed(1);
      final distance = data.distanceFromUser;
      final distanceSuffix = distance != null
          ? ' • ${distance.toStringAsFixed(0)}m away'
          : '';

      content = Row(
        children: [
          isLoading
              ? SizedBox(
                  width: 44,
                  height: 44,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: cs.primary,
                  ),
                )
              : const Icon(
                  Icons.star_rounded,
                  color: Color(0xFFFFB300),
                  size: 44,
                ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Best Study Spot (${strategy == 'occupancyRate' ? 'Quietest' : 'Closest'})',
                  style: tt.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '$libraryName\n$area',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '$percentage% Occupied$distanceSuffix',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: cs.primaryContainer.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: cs.primary.withValues(alpha: 0.25)),
          ),
          child: content,
        ),
        Positioned(
          top: 0,
          right: 0,
          child: PopupMenuButton<String>(
            icon: Icon(Icons.tune, color: cs.primary),
            onSelected: onStrategyChanged,
            itemBuilder: (_) => const [
              PopupMenuItem<String>(
                value: 'occupancyRate',
                child: Text('Prioritize Quietest'),
              ),
              PopupMenuItem<String>(
                value: 'distance',
                child: Text('Prioritize Closest'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
