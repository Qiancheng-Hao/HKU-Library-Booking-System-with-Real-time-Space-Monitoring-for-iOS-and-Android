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

  @override
  void initState() {
    super.initState();
    _selectedFloor = widget.initialFloor;
  }

  @override
  Widget build(BuildContext context) {
    final displayedItems = widget.facilities.where((item) {
      final itemFloor = item['floor'] as int? ?? 1;
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
                  selectedColor: Colors.teal[100],
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.teal[900] : Colors.black,
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
            color: Colors.grey[200],
            width: double.infinity,
            child: ClipRect(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  double mapBaseWidth = 100.0;
                  double mapBaseHeight = 100.0;

                  for (var item in displayedItems) {
                    final x = (item['x_coordinate'] ?? 0) as int;
                    final y = (item['y_coordinate'] ?? 0) as int;
                    final w = (item['width'] ?? 0) as int;
                    final h = (item['height'] ?? 0) as int;

                    if (x + w > mapBaseWidth) {
                      mapBaseWidth = (x + w).toDouble();
                    }
                    if (y + h > mapBaseHeight) {
                      mapBaseHeight = (y + h).toDouble();
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
                                painter: GridPainter(),
                                child: Container(color: Colors.white),
                              ),
                            ),

                            ...displayedItems.map((item) {
                              final x = (item['x_coordinate'] ?? 50) as int;
                              final y = (item['y_coordinate'] ?? 50) as int;
                              final wPercent = (item['width'] ?? 0) as int;
                              final hPercent = (item['height'] ?? 0) as int;

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
    final type = (item['type'] as String? ?? '').toLowerCase();
    final name = item['name'] as String? ?? '';

    String identifier = name;
    final nameParts = name.split(' ');
    if (nameParts.length > 1) {
      identifier = nameParts.last;
    }

    double defaultWidth = 30;
    double defaultHeight = 30;
    Color baseColor = Colors.teal;
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
        fillColor = Colors.grey.withValues(alpha: 0.1);
        borderColor = Colors.grey.withValues(alpha: 0.3);
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
                    ? Colors.grey
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
                    ? Colors.white
                    : Colors.black87,
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
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.teal.withValues(alpha: 0.1)
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
