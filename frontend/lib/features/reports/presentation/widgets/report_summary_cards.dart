import 'package:flutter/material.dart';

import '../../../../core/models/report.dart';
import '../../../../theme/app_theme.dart';

class ReportSummaryCards extends StatelessWidget {
  final ReportSummary summary;

  const ReportSummaryCards({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final items = <_SummaryItem>[
      _SummaryItem(
        icon: Icons.percent_rounded,
        label: 'Average',
        value: _formatRate(summary.averageOccupancyRate),
      ),
      _SummaryItem(
        icon: Icons.trending_up_rounded,
        label: 'Peak',
        value: _formatRate(summary.peakOccupancyRate),
      ),
      _SummaryItem(
        icon: Icons.calendar_month_outlined,
        label: 'Busiest Day',
        value: summary.busiestWeekday?.weekdayName ?? '-',
        detail: summary.busiestWeekday == null
            ? 'No pattern yet'
            : _formatRate(summary.busiestWeekday!.averageOccupancyRate),
      ),
      _SummaryItem(
        icon: Icons.light_mode_outlined,
        label: 'Quiet Window',
        value: summary.suggestedLowTrafficHour?.label ?? '-',
        detail: summary.suggestedLowTrafficHour == null
            ? 'No pattern yet'
            : _formatRate(
                summary.suggestedLowTrafficHour!.averageOccupancyRate,
              ),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 680 ? 4 : 2;
        final tileWidth =
            (constraints.maxWidth - AppSpacing.md * (crossAxisCount - 1)) /
            crossAxisCount;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            for (final item in items)
              SizedBox(
                width: tileWidth,
                child: _SummaryTile(item: item),
              ),
          ],
        );
      },
    );
  }

  String _formatRate(double? value) {
    if (value == null) return '-';
    return '${value.clamp(0, 100).toStringAsFixed(1)}%';
  }
}

class _SummaryItem {
  final IconData icon;
  final String label;
  final String value;
  final String? detail;

  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.value,
    this.detail,
  });
}

class _SummaryTile extends StatelessWidget {
  final _SummaryItem item;

  const _SummaryTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(item.icon, color: cs.primary),
            const SizedBox(height: AppSpacing.md),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              item.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: cs.primary,
              ),
            ),
            if (item.detail != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                item.detail!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
