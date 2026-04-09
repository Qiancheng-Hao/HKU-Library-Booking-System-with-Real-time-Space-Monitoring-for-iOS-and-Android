import 'package:flutter/material.dart';

class LibraryMapViewer extends StatelessWidget {
  final List<dynamic> facilities;
  final int? highlightFacilityId;
  final Function(dynamic facility)? onFacilityTap;
  final int? initialFloor;

  const LibraryMapViewer({
    super.key,
    required this.facilities,
    this.highlightFacilityId,
    this.onFacilityTap,
    this.initialFloor,
  });

  @override
  Widget build(BuildContext context) {
    final Set<int> floors = {};
    for (var item in facilities) {
      floors.add(item['floor'] as int? ?? 1);
    }
    final sortedFloors = floors.toList()..sort();

    int selectedFloor = 1;
    if (sortedFloors.isNotEmpty) selectedFloor = sortedFloors.first;

    if (highlightFacilityId != null) {
      final highlightItem = facilities.firstWhere(
        (f) => f['id'] == highlightFacilityId,
        orElse: () => null,
      );
      if (highlightItem != null) {
        selectedFloor = highlightItem['floor'] as int? ?? 1;
      }
    } else if (initialFloor != null && sortedFloors.contains(initialFloor)) {
      selectedFloor = initialFloor!;
    }

    return _LibraryMapContent(
      facilities: facilities,
      initialFloor: selectedFloor,
      sortedFloors: sortedFloors,
      highlightFacilityId: highlightFacilityId,
      onFacilityTap: onFacilityTap,
    );
  }
}

class _LibraryMapContent extends StatefulWidget {
  final List<dynamic> facilities;
  final int initialFloor;
  final List<int> sortedFloors;
  final int? highlightFacilityId;
  final Function(dynamic facility)? onFacilityTap;

  const _LibraryMapContent({
    required this.facilities,
    required this.initialFloor,
    required this.sortedFloors,
    this.highlightFacilityId,
    this.onFacilityTap,
  });

  @override
  State<_LibraryMapContent> createState() => _LibraryMapContentState();
}

class _LibraryMapContentState extends State<_LibraryMapContent> {
  late int _selectedFloor;

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is num) return value.toInt();
    return fallback;
  }

  double _toDouble(dynamic value, {double fallback = 0}) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return fallback;
  }

  @override
  void initState() {
    super.initState();
    _selectedFloor = widget.initialFloor;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final displayedItems = widget.facilities.where((item) {
      final itemFloor = _toInt(item['floor'], fallback: 1);
      return itemFloor == _selectedFloor;
    }).toList();

    return Column(
      children: [
        // Floor Selector
        if (widget.sortedFloors.length > 1)
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.sortedFloors.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final floor = widget.sortedFloors[index];
                final isSelected = floor == _selectedFloor;
                return ChoiceChip(
                  label: Text("Floor $floor"),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedFloor = floor);
                    }
                  },
                  selectedColor: cs.primaryContainer,
                  backgroundColor: cs.surfaceContainerHigh,
                  labelStyle: TextStyle(
                    color: isSelected ? cs.onPrimaryContainer : cs.onSurface,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                );
              },
            ),
          ),

        // Map Area
        Expanded(
          child: Container(
            color: cs.surfaceContainerLow,
            width: double.infinity,
            child: ClipRect(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  double mapBaseWidth = 100.0;
                  double mapBaseHeight = 100.0;

                  for (var item in displayedItems) {
                    final x = _toDouble(item['x_coordinate']);
                    final y = _toDouble(item['y_coordinate']);
                    final w = _toDouble(item['width']);
                    final h = _toDouble(item['height']);

                    if (x + w > mapBaseWidth) {
                      mapBaseWidth = x + w;
                    }
                    if (y + h > mapBaseHeight) {
                      mapBaseHeight = y + h;
                    }
                  }

                  mapBaseWidth *= 1.05;
                  mapBaseHeight *= 1.05;

                  return InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 4.0,
                    boundaryMargin: EdgeInsets.zero,
                    constrained: true,
                    child: Center(
                      child: SizedBox(
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: CustomPaint(
                                painter: GridPainter(
                                  lineColor: cs.primary.withValues(alpha: 0.10),
                                ),
                                child: Container(color: cs.surface),
                              ),
                            ),

                            ...displayedItems.map((item) {
                              final x = _toDouble(
                                item['x_coordinate'],
                                fallback: 50,
                              );
                              final y = _toDouble(
                                item['y_coordinate'],
                                fallback: 50,
                              );
                              final wPercent = _toDouble(item['width']);
                              final hPercent = _toDouble(item['height']);

                              final left =
                                  (x / mapBaseWidth) * constraints.maxWidth;
                              final top =
                                  (y / mapBaseHeight) * constraints.maxHeight;

                              final double? pixelWidth = wPercent > 0
                                  ? (wPercent / mapBaseWidth) *
                                        constraints.maxWidth
                                  : null;
                              final double? pixelHeight = hPercent > 0
                                  ? (hPercent / mapBaseHeight) *
                                        constraints.maxHeight
                                  : null;

                              final isHighlighted =
                                  widget.highlightFacilityId == item['id'];

                              return Positioned(
                                left: left,
                                top: top,
                                child: GestureDetector(
                                  onTap: widget.onFacilityTap != null
                                      ? () => widget.onFacilityTap!(item)
                                      : null,
                                  child: _buildFacilityMarker(
                                    item,
                                    pixelWidth,
                                    pixelHeight,
                                    isHighlighted,
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFacilityMarker(
    dynamic item,
    double? pixelWidth,
    double? pixelHeight,
    bool isHighlighted,
  ) {
    final cs = Theme.of(context).colorScheme;
    final type = (item['type'] as String? ?? '').toLowerCase();
    final name = item['name'] as String? ?? '';
    String identifier = _getMarkerLabel(name);

    double defaultWidth = 30;
    double defaultHeight = 30;
    Color baseColor = cs.primary;
    IconData? icon;

    if (type.contains('room')) {
      defaultWidth = 60;
      defaultHeight = 40;
      baseColor = Colors.orange;
      icon = Icons.groups;
    } else if (type.contains('desk') || type.contains('table')) {
      defaultWidth = 40;
      defaultHeight = 25;
      baseColor = Colors.blue;
      icon = Icons.table_restaurant;
    } else if (type.contains('booth')) {
      defaultWidth = 35;
      defaultHeight = 35;
      baseColor = Colors.purple;
      icon = Icons.chair;
    }

    // Highlighting Logic
    Color fillColor;
    Color borderColor;

    if (widget.highlightFacilityId != null) {
      if (isHighlighted) {
        fillColor = baseColor.withValues(alpha: 0.9);
        borderColor = baseColor.withValues(alpha: 1.0);
      } else {
        fillColor = cs.onSurface.withValues(alpha: 0.06);
        borderColor = cs.onSurface.withValues(alpha: 0.2);
      }
    } else {
      fillColor = baseColor.withValues(alpha: 0.2);
      borderColor = baseColor;
    }

    final double width = pixelWidth ?? defaultWidth;
    final double height = pixelHeight ?? defaultHeight;
    final double iconSize = (width < height ? width : height) - 4;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: fillColor,
        border: Border.all(color: borderColor, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (icon != null &&
              (!isHighlighted || widget.highlightFacilityId == null))
            Opacity(
              opacity: isHighlighted ? 0.5 : 0.2,
              child: Icon(
                icon,
                size: iconSize > 0 ? iconSize : 0,
                color: widget.highlightFacilityId != null && !isHighlighted
                    ? cs.onSurfaceVariant
                    : borderColor,
              ),
            ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: Text(
              identifier,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: (widget.highlightFacilityId != null && isHighlighted)
                    ? cs.onPrimary
                    : cs.onSurface,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  String _getMarkerLabel(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    final parts = trimmed.split(RegExp(r'\s+'));
    return parts.last;
  }
}

class GridPainter extends CustomPainter {
  final Color lineColor;
  GridPainter({this.lineColor = const Color(0x1A009688)});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1;

    const double gridSize = 40;

    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
