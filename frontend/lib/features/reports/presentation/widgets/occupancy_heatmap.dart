import 'package:flutter/material.dart';

import '../../../../core/models/report.dart';
import '../../../../theme/app_theme.dart';

class OccupancyHeatmap extends StatelessWidget {
  final ReportHeatmap heatmap;

  const OccupancyHeatmap({super.key, required this.heatmap});

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
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.grid_view_rounded, color: cs.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Weekly Heatmap',
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '2-hour blocks',
                  style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            if (heatmap.cells.isEmpty)
              SizedBox(
                height: 150,
                child: Center(
                  child: _HeatmapEmptyMessage(
                    title: 'No heatmap data yet',
                    message:
                        'Weekly patterns will appear after snapshots are collected.',
                  ),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: _HeatmapGrid(cells: heatmap.cells),
              ),
          ],
        ),
      ),
    );
  }
}

class _HeatmapGrid extends StatefulWidget {
  final List<ReportHeatmapCell> cells;

  const _HeatmapGrid({required this.cells});

  @override
  State<_HeatmapGrid> createState() => _HeatmapGridState();
}

class _HeatmapGridState extends State<_HeatmapGrid> {
  _HeatmapSlot? _selectedSlot;

  static const _labelWidth = 42.0;
  static const _slotWidth = 24.0;
  static const _cellWidth = 22.0;
  static const _gridWidth = _labelWidth + 12 * _slotWidth;
  static const _weekdayOrder = [1, 2, 3, 4, 5, 6, 0];
  static const _weekdayLabels = {
    0: 'Sun',
    1: 'Mon',
    2: 'Tue',
    3: 'Wed',
    4: 'Thu',
    5: 'Fri',
    6: 'Sat',
  };

  @override
  void didUpdateWidget(covariant _HeatmapGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.cells, widget.cells)) {
      _selectedSlot = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bySlot = _buildBlocks(widget.cells);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(width: _labelWidth),
            for (var hour = 0; hour < 24; hour += 2)
              SizedBox(
                width: _slotWidth,
                child: hour % 4 == 0
                    ? Text(
                        '$hour',
                        textAlign: TextAlign.center,
                        style: tt.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        for (final weekday in _weekdayOrder)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              children: [
                SizedBox(
                  width: _labelWidth,
                  child: Text(
                    _weekdayLabels[weekday] ?? 'Day',
                    style: tt.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                for (var hour = 0; hour < 24; hour += 2)
                  _HeatmapCell(
                    slot: _HeatmapSlot(
                      weekdayIndex: weekday,
                      weekdayName: _weekdayLabels[weekday] ?? 'Day',
                      startHour: hour,
                      block: bySlot['$weekday:$hour'],
                    ),
                    isSelected: _selectedSlot?.key == '$weekday:$hour',
                    cellWidth: _cellWidth,
                    onSelected: _selectSlot,
                    onCleared: _clearSelection,
                  ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        _HeatmapDetails(slot: _selectedSlot, width: _gridWidth),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Text(
              'Quiet',
              style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(width: AppSpacing.sm),
            for (final rate in const [15.0, 35.0, 55.0, 75.0, 95.0])
              Container(
                width: 24,
                height: 10,
                color: _rateColor(context, rate),
              ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Busy',
              style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ],
    );
  }

  void _selectSlot(_HeatmapSlot slot) {
    if (_selectedSlot?.key == slot.key) return;
    setState(() => _selectedSlot = slot);
  }

  void _clearSelection(_HeatmapSlot slot) {
    if (_selectedSlot?.key != slot.key) return;
    setState(() => _selectedSlot = null);
  }

  Map<String, _HeatmapBlock> _buildBlocks(List<ReportHeatmapCell> cells) {
    final grouped = <String, List<ReportHeatmapCell>>{};
    for (final cell in cells) {
      final startHour = (cell.hour ~/ 2) * 2;
      grouped
          .putIfAbsent('${cell.weekdayIndex}:$startHour', () => [])
          .add(cell);
    }

    return {
      for (final entry in grouped.entries)
        entry.key: _HeatmapBlock.fromCells(entry.value),
    };
  }
}

class _HeatmapCell extends StatelessWidget {
  final _HeatmapSlot slot;
  final bool isSelected;
  final double cellWidth;
  final ValueChanged<_HeatmapSlot> onSelected;
  final ValueChanged<_HeatmapSlot> onCleared;

  const _HeatmapCell({
    required this.slot,
    required this.isSelected,
    required this.cellWidth,
    required this.onSelected,
    required this.onCleared,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final current = slot.block;
    final color = current == null
        ? cs.surfaceContainerHighest.withValues(alpha: 0.45)
        : _rateColor(context, current.averageOccupancyRate);
    final label = current == null
        ? '${slot.weekdayName} ${slot.hourLabel}: no data'
        : '${current.weekdayName} ${current.hourLabel}: '
              '${current.averageOccupancyRate.toStringAsFixed(1)}% average, '
              '${current.peakOccupancyRate.toStringAsFixed(1)}% peak';

    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        button: true,
        child: MouseRegion(
          onEnter: (_) => onSelected(slot),
          onHover: (_) => onSelected(slot),
          onExit: (_) => onCleared(slot),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => onSelected(slot),
            onLongPressStart: (_) => onSelected(slot),
            child: Container(
              width: cellWidth,
              height: 18,
              margin: const EdgeInsets.only(right: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: isSelected
                      ? cs.onSurface
                      : cs.outlineVariant.withValues(alpha: 0.18),
                  width: isSelected ? 1.6 : 0.6,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeatmapDetails extends StatelessWidget {
  final _HeatmapSlot? slot;
  final double width;

  const _HeatmapDetails({required this.slot, required this.width});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final current = slot;

    return Container(
      height: 54,
      width: width,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: current == null
          ? Align(
              alignment: Alignment.center,
              child: Text(
                'Tap a block to view details',
                textAlign: TextAlign.center,
                style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 96,
                  child: Text(
                    '${current.weekdayName}\n${current.hourLabel}',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tt.labelMedium?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                if (current.block == null)
                  Expanded(
                    child: Text(
                      'No data',
                      textAlign: TextAlign.center,
                      style: tt.labelMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  )
                else ...[
                  Expanded(
                    child: _HeatmapMetric(
                      label: 'Average',
                      value:
                          '${current.block!.averageOccupancyRate.toStringAsFixed(1)}%',
                    ),
                  ),
                  Expanded(
                    child: _HeatmapMetric(
                      label: 'Peak',
                      value:
                          '${current.block!.peakOccupancyRate.toStringAsFixed(1)}%',
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _HeatmapEmptyMessage extends StatelessWidget {
  final String title;
  final String message;

  const _HeatmapEmptyMessage({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.grid_view_rounded, color: cs.onSurfaceVariant, size: 28),
        const SizedBox(height: AppSpacing.sm),
        Text(
          title,
          textAlign: TextAlign.center,
          style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          message,
          textAlign: TextAlign.center,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _HeatmapMetric extends StatelessWidget {
  final String label;
  final String value;

  const _HeatmapMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: tt.labelMedium?.copyWith(
            color: cs.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _HeatmapSlot {
  final int weekdayIndex;
  final String weekdayName;
  final int startHour;
  final _HeatmapBlock? block;

  const _HeatmapSlot({
    required this.weekdayIndex,
    required this.weekdayName,
    required this.startHour,
    required this.block,
  });

  String get key => '$weekdayIndex:$startHour';

  String get hourLabel {
    final endHour = (startHour + 2) % 24;
    final start = startHour.toString().padLeft(2, '0');
    final end = endHour.toString().padLeft(2, '0');
    return '$start:00-$end:00';
  }
}

class _HeatmapBlock {
  final int weekdayIndex;
  final String weekdayName;
  final int startHour;
  final int endHour;
  final double averageOccupancyRate;
  final double peakOccupancyRate;
  final int sampleCount;

  const _HeatmapBlock({
    required this.weekdayIndex,
    required this.weekdayName,
    required this.startHour,
    required this.endHour,
    required this.averageOccupancyRate,
    required this.peakOccupancyRate,
    required this.sampleCount,
  });

  factory _HeatmapBlock.fromCells(List<ReportHeatmapCell> cells) {
    final sorted = [...cells]..sort((a, b) => a.hour.compareTo(b.hour));
    final first = sorted.first;
    final startHour = (first.hour ~/ 2) * 2;
    final totalSamples = sorted.fold<int>(
      0,
      (sum, cell) => sum + cell.sampleCount,
    );
    final weightedAverage = totalSamples > 0
        ? sorted.fold<double>(
                0,
                (sum, cell) =>
                    sum + cell.averageOccupancyRate * cell.sampleCount,
              ) /
              totalSamples
        : sorted.fold<double>(
                0,
                (sum, cell) => sum + cell.averageOccupancyRate,
              ) /
              sorted.length;

    return _HeatmapBlock(
      weekdayIndex: first.weekdayIndex,
      weekdayName: first.weekdayName,
      startHour: startHour,
      endHour: (startHour + 2) % 24,
      averageOccupancyRate: weightedAverage,
      peakOccupancyRate: sorted
          .map((cell) => cell.peakOccupancyRate)
          .reduce((a, b) => a > b ? a : b),
      sampleCount: totalSamples,
    );
  }

  String get hourLabel {
    final start = startHour.toString().padLeft(2, '0');
    final end = endHour.toString().padLeft(2, '0');
    return '$start:00-$end:00';
  }
}

Color _rateColor(BuildContext context, double rate) {
  final cs = Theme.of(context).colorScheme;
  final normalized = rate.clamp(0.0, 100.0).toDouble() / 100.0;
  if (normalized < 0.34) {
    return Color.lerp(
      cs.surfaceContainerHighest,
      AppColors.statusAvailable,
      normalized / 0.34,
    )!;
  }
  if (normalized < 0.72) {
    return Color.lerp(
      AppColors.statusAvailable,
      AppColors.statusModerate,
      (normalized - 0.34) / 0.38,
    )!;
  }
  return Color.lerp(
    AppColors.statusModerate,
    AppColors.statusBusy,
    (normalized - 0.72) / 0.28,
  )!;
}
