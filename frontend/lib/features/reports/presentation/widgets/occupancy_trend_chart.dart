import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/models/report.dart';
import '../../../../theme/app_theme.dart';

const _chartLeftPadding = 34.0;
const _chartTopPadding = 8.0;
const _chartRightPadding = 4.0;
const _chartBottomPadding = 10.0;

class OccupancyTrendChart extends StatefulWidget {
  final ReportTrend trend;
  final int selectedDays;
  final bool isLoading;
  final ValueChanged<int> onDaysChanged;

  const OccupancyTrendChart({
    super.key,
    required this.trend,
    required this.selectedDays,
    required this.isLoading,
    required this.onDaysChanged,
  });

  @override
  State<OccupancyTrendChart> createState() => _OccupancyTrendChartState();
}

class _OccupancyTrendChartState extends State<OccupancyTrendChart> {
  int? _selectedIndex;

  @override
  void didUpdateWidget(covariant OccupancyTrendChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selected = _selectedIndex;
    if (selected != null && selected >= widget.trend.points.length) {
      _selectedIndex = widget.trend.points.isEmpty
          ? null
          : widget.trend.points.length - 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final points = widget.trend.points;

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
                Icon(Icons.show_chart_rounded, color: cs.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Occupancy Trend',
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _TrendRangeSelector(
                  selectedDays: widget.selectedDays,
                  isLoading: widget.isLoading,
                  onChanged: widget.onDaysChanged,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                _LegendDot(color: cs.primary, label: 'Average'),
                const SizedBox(width: AppSpacing.md),
                _LegendDot(color: AppColors.statusModerate, label: 'Peak'),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (points.isEmpty)
              SizedBox(
                height: 180,
                child: Center(
                  child: _ChartEmptyMessage(
                    icon: Icons.show_chart_rounded,
                    title: 'No trend data yet',
                    message:
                        'This library has no occupancy buckets for this range.',
                  ),
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final size = Size(
                          constraints.maxWidth,
                          constraints.maxHeight,
                        );
                        final selected = _selectedIndex == null
                            ? null
                            : points[_selectedIndex!];
                        final selectedX = _selectedIndex == null
                            ? null
                            : _pointX(size, points.length, _selectedIndex!);
                        return MouseRegion(
                          onHover: (event) =>
                              _selectPoint(event.localPosition, size),
                          onExit: (_) => setState(() => _selectedIndex = null),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapDown: (details) =>
                                _selectPoint(details.localPosition, size),
                            onHorizontalDragStart: (details) =>
                                _selectPoint(details.localPosition, size),
                            onHorizontalDragUpdate: (details) =>
                                _selectPoint(details.localPosition, size),
                            onHorizontalDragEnd: (_) =>
                                setState(() => _selectedIndex = null),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                CustomPaint(
                                  size: size,
                                  painter: _TrendPainter(
                                    points: points,
                                    lineColor: cs.primary,
                                    peakColor: AppColors.statusModerate,
                                    gridColor: cs.outline.withValues(
                                      alpha: 0.5,
                                    ),
                                    axisLabelColor: cs.onSurfaceVariant
                                        .withValues(alpha: 0.82),
                                    fillColor: cs.primary.withValues(
                                      alpha: 0.10,
                                    ),
                                    selectedIndex: _selectedIndex,
                                  ),
                                ),
                                if (selected != null && selectedX != null)
                                  Positioned(
                                    left: (selectedX - 78).clamp(
                                      0.0,
                                      math.max(0, size.width - 156),
                                    ),
                                    top: 0,
                                    child: _TrendTooltip(
                                      label: _formatBucketLabel(selected),
                                      average: selected.averageOccupancyRate,
                                      peak: selected.peakOccupancyRate,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _formatBucketLabel(points.first),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          _formatBucketLabel(points.last),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _formatBucketLabel(ReportTrendPoint point) {
    final backendLabel = _formatBackendBucketLabel(point.bucketLabel);
    if (backendLabel != null) return backendLabel;

    final date = point.bucketStart;
    if (date == null) return point.bucketLabel;
    final month = months[date.month - 1];
    if (widget.trend.bucket == 'day') return '$month ${date.day}';
    final hour = date.hour.toString().padLeft(2, '0');
    return '$month ${date.day}, $hour:00';
  }

  String? _formatBackendBucketLabel(String label) {
    final match = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})(?:[ T](\d{2}):\d{2})?',
    ).firstMatch(label);
    if (match == null) return null;

    final monthNumber = int.tryParse(match.group(2) ?? '');
    final dayNumber = int.tryParse(match.group(3) ?? '');
    if (monthNumber == null ||
        monthNumber < 1 ||
        monthNumber > 12 ||
        dayNumber == null) {
      return null;
    }

    final month = months[monthNumber - 1];
    if (widget.trend.bucket == 'day') return '$month $dayNumber';

    final hour = match.group(4);
    if (hour == null) return '$month $dayNumber';
    return '$month $dayNumber, $hour:00';
  }

  void _selectPoint(Offset localPosition, Size size) {
    final points = widget.trend.points;
    if (points.isEmpty) return;
    final chart = _chartRect(size);
    final clampedX = localPosition.dx.clamp(chart.left, chart.right).toDouble();
    final ratio = chart.width <= 0
        ? 0.0
        : (clampedX - chart.left) / chart.width;
    final index = points.length == 1
        ? 0
        : (ratio * (points.length - 1)).round().clamp(0, points.length - 1);
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
  }
}

const months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

Rect _chartRect(Size size) {
  return Rect.fromLTWH(
    _chartLeftPadding,
    _chartTopPadding,
    math.max(1, size.width - _chartLeftPadding - _chartRightPadding),
    math.max(1, size.height - _chartTopPadding - _chartBottomPadding),
  );
}

double _pointX(Size size, int count, int index) {
  final chart = _chartRect(size);
  if (count <= 1) return chart.left + chart.width / 2;
  return chart.left + chart.width * index / (count - 1);
}

class _TrendTooltip extends StatelessWidget {
  final String label;
  final double average;
  final double peak;

  const _TrendTooltip({
    required this.label,
    required this.average,
    required this.peak,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Material(
      elevation: 4,
      color: cs.inverseSurface,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        width: 156,
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.labelMedium?.copyWith(
                color: cs.onInverseSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            _TooltipValue(color: cs.primary, label: 'Average', value: average),
            const SizedBox(height: 2),
            _TooltipValue(
              color: AppColors.statusModerate,
              label: 'Peak',
              value: peak,
            ),
          ],
        ),
      ),
    );
  }
}

class _TooltipValue extends StatelessWidget {
  final Color color;
  final String label;
  final double value;

  const _TooltipValue({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            label,
            style: tt.labelSmall?.copyWith(color: cs.onInverseSurface),
          ),
        ),
        Text(
          '${value.clamp(0, 100).toStringAsFixed(1)}%',
          style: tt.labelSmall?.copyWith(
            color: cs.onInverseSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _TrendRangeSelector extends StatelessWidget {
  final int selectedDays;
  final bool isLoading;
  final ValueChanged<int> onChanged;

  const _TrendRangeSelector({
    required this.selectedDays,
    required this.isLoading,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SegmentedButton<int>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment<int>(value: 1, label: Text('Day')),
        ButtonSegment<int>(value: 7, label: Text('Week')),
        ButtonSegment<int>(value: 30, label: Text('Month')),
      ],
      selected: {selectedDays},
      onSelectionChanged: isLoading
          ? null
          : (values) {
              if (values.isNotEmpty) onChanged(values.first);
            },
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
        textStyle: WidgetStatePropertyAll(
          Theme.of(context).textTheme.labelSmall,
        ),
        side: WidgetStatePropertyAll(BorderSide(color: cs.outlineVariant)),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<ReportTrendPoint> points;
  final Color lineColor;
  final Color peakColor;
  final Color gridColor;
  final Color axisLabelColor;
  final Color fillColor;
  final int? selectedIndex;

  const _TrendPainter({
    required this.points,
    required this.lineColor,
    required this.peakColor,
    required this.gridColor,
    required this.axisLabelColor,
    required this.fillColor,
    this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final chart = _chartRect(size);

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (final fraction in const [0.0, 0.5, 1.0]) {
      final y = chart.top + chart.height * fraction;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
    }

    final values = points
        .map((point) => point.averageOccupancyRate.clamp(0.0, 100.0).toDouble())
        .toList();
    final peakValues = points
        .map((point) => point.peakOccupancyRate.clamp(0.0, 100.0).toDouble())
        .toList();

    final path = _buildLinePath(chart, values);
    final peakPath = _buildLinePath(chart, peakValues);
    final fillPath = Path.from(path);
    fillPath.lineTo(chart.right, chart.bottom);
    fillPath.lineTo(chart.left, chart.bottom);
    fillPath.close();

    canvas.drawPath(
      peakPath,
      Paint()
        ..color = peakColor.withValues(alpha: 0.72)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(fillPath, Paint()..color = fillColor);
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final selected = selectedIndex;
    if (selected != null && selected >= 0 && selected < values.length) {
      final x = _pointX(size, values.length, selected);
      canvas.drawLine(
        Offset(x, chart.top),
        Offset(x, chart.bottom),
        Paint()
          ..color = gridColor.withValues(alpha: 0.75)
          ..strokeWidth = 1,
      );
    }

    final dotPaint = Paint()..color = lineColor;
    final peakDotPaint = Paint()..color = peakColor;
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? chart.left + chart.width / 2
          : chart.left + chart.width * i / (values.length - 1);
      final avgY = chart.bottom - chart.height * values[i] / 100;
      final peakY = chart.bottom - chart.height * peakValues[i] / 100;
      canvas.drawCircle(Offset(x, peakY), 3.2, peakDotPaint);
      canvas.drawCircle(Offset(x, avgY), 3.5, dotPaint);
    }

    if (selected != null && selected >= 0 && selected < values.length) {
      final x = _pointX(size, values.length, selected);
      final avgY = chart.bottom - chart.height * values[selected] / 100;
      final peakY = chart.bottom - chart.height * peakValues[selected] / 100;
      canvas.drawCircle(Offset(x, peakY), 5, Paint()..color = peakColor);
      canvas.drawCircle(Offset(x, peakY), 2.4, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(x, avgY), 6, Paint()..color = lineColor);
      canvas.drawCircle(Offset(x, avgY), 3, Paint()..color = Colors.white);
    }

    _drawAxisLabel(canvas, '100%', Offset(0, chart.top - 6), axisLabelColor);
    _drawAxisLabel(
      canvas,
      '50%',
      Offset(6, chart.top + chart.height / 2 - 7),
      axisLabelColor,
    );
    _drawAxisLabel(canvas, '0%', Offset(14, chart.bottom - 8), axisLabelColor);
  }

  Path _buildLinePath(Rect chart, List<double> values) {
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? chart.left + chart.width / 2
          : chart.left + chart.width * i / (values.length - 1);
      final y = chart.bottom - chart.height * values[i] / 100;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    return path;
  }

  void _drawAxisLabel(Canvas canvas, String text, Offset offset, Color color) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.peakColor != peakColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.axisLabelColor != axisLabelColor ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.selectedIndex != selectedIndex;
  }
}

class _ChartEmptyMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _ChartEmptyMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: cs.onSurfaceVariant, size: 28),
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
