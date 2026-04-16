import 'package:flutter/material.dart';
import '../../models/facility.dart';

class LibraryMapViewer extends StatelessWidget {
  final List<Facility> facilities;
  final int? highlightFacilityId;
  final Function(Facility facility)? onFacilityTap;
  final int? initialFloor;
  final Set<String>? availableFacilityNames;
  final Set<String>? selectedFacilityNames;
  final Function(String markerLabel)? onFacilityNameTap;

  const LibraryMapViewer({
    super.key,
    required this.facilities,
    this.highlightFacilityId,
    this.onFacilityTap,
    this.initialFloor,
    this.availableFacilityNames,
    this.selectedFacilityNames,
    this.onFacilityNameTap,
  });

  @override
  Widget build(BuildContext context) {
    final Set<int> floors = {};
    for (var item in facilities) {
      floors.add(item.floor);
    }
    final sortedFloors = floors.toList()..sort();

    int selectedFloor = sortedFloors.isNotEmpty ? sortedFloors.first : 1;

    if (availableFacilityNames != null && availableFacilityNames!.isNotEmpty) {
      final Map<int, int> floorAvailableCount = {};
      for (var item in facilities) {
        final floor = item.floor;
        final label = _markerLabel(item.name);
        final name = item.name.toLowerCase();
        final isAvailable = availableFacilityNames!.any(
          (n) =>
              n.toLowerCase() == label.toLowerCase() || n.toLowerCase() == name,
        );
        if (isAvailable) {
          floorAvailableCount[floor] = (floorAvailableCount[floor] ?? 0) + 1;
        }
      }
      if (floorAvailableCount.isNotEmpty) {
        selectedFloor = floorAvailableCount.entries
            .reduce((a, b) => a.value >= b.value ? a : b)
            .key;
      }
    } else if (highlightFacilityId != null) {
      final highlightItem = facilities.firstWhere(
        (f) => f.id == highlightFacilityId,
        orElse: () => const Facility(
          id: -1,
          name: '',
          type: '',
          floor: 1,
          xCoordinate: 0,
          yCoordinate: 0,
          width: 0,
          height: 0,
        ),
      );
      if (highlightItem.id != -1) {
        selectedFloor = highlightItem.floor;
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
      availableFacilityNames: availableFacilityNames,
      selectedFacilityNames: selectedFacilityNames,
      onFacilityNameTap: onFacilityNameTap,
    );
  }

  static String _markerLabel(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.split(RegExp(r'\s+')).last;
  }
}

class _LibraryMapContent extends StatefulWidget {
  final List<Facility> facilities;
  final int initialFloor;
  final List<int> sortedFloors;
  final int? highlightFacilityId;
  final Function(Facility facility)? onFacilityTap;
  final Set<String>? availableFacilityNames;
  final Set<String>? selectedFacilityNames;
  final Function(String markerLabel)? onFacilityNameTap;

  const _LibraryMapContent({
    required this.facilities,
    required this.initialFloor,
    required this.sortedFloors,
    this.highlightFacilityId,
    this.onFacilityTap,
    this.availableFacilityNames,
    this.selectedFacilityNames,
    this.onFacilityNameTap,
  });

  @override
  State<_LibraryMapContent> createState() => _LibraryMapContentState();
}

class _LibraryMapContentState extends State<_LibraryMapContent> {
  late int _selectedFloor;

  String _getMarkerLabel(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.split(RegExp(r'\s+')).last;
  }

  bool _isFacilityAvailable(Facility item) {
    final names = widget.availableFacilityNames;
    if (names == null) return true;
    final fullName = item.name.toLowerCase();
    final label = _getMarkerLabel(item.name).toLowerCase();
    return names.any(
      (n) => n.toLowerCase() == label || n.toLowerCase() == fullName,
    );
  }

  bool _isFacilitySelected(Facility item) {
    final names = widget.selectedFacilityNames;
    if (names == null) return false;
    final fullName = item.name.toLowerCase();
    final label = _getMarkerLabel(item.name).toLowerCase();
    return names.any(
      (n) => n.toLowerCase() == label || n.toLowerCase() == fullName,
    );
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
      return item.floor == _selectedFloor;
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
                    if (selected) setState(() => _selectedFloor = floor);
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
                    final x = item.xCoordinate;
                    final y = item.yCoordinate;
                    final w = item.width;
                    final h = item.height;
                    if (x + w > mapBaseWidth) mapBaseWidth = x + w;
                    if (y + h > mapBaseHeight) mapBaseHeight = y + h;
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
                              final x = item.xCoordinate == 0
                                  ? 50.0
                                  : item.xCoordinate;
                              final y = item.yCoordinate == 0
                                  ? 50.0
                                  : item.yCoordinate;
                              final wPercent = item.width;
                              final hPercent = item.height;

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
                                  widget.highlightFacilityId == item.id;

                              final isAvailable =
                                  widget.availableFacilityNames != null
                                  ? _isFacilityAvailable(item)
                                  : true;
                              final isSelected = _isFacilitySelected(item);

                              VoidCallback? onTap;
                              if (widget.availableFacilityNames != null) {
                                if (isAvailable &&
                                    widget.onFacilityNameTap != null) {
                                  final label = _getMarkerLabel(item.name);
                                  onTap = () =>
                                      widget.onFacilityNameTap!(label);
                                }
                              } else if (widget.onFacilityTap != null) {
                                onTap = () => widget.onFacilityTap!(item);
                              }

                              return Positioned(
                                left: left,
                                top: top,
                                child: GestureDetector(
                                  onTap: onTap,
                                  child: _buildFacilityMarker(
                                    item,
                                    pixelWidth,
                                    pixelHeight,
                                    isHighlighted,
                                    isAvailable: isAvailable,
                                    isSelected: isSelected,
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
    Facility item,
    double? pixelWidth,
    double? pixelHeight,
    bool isHighlighted, {
    bool isAvailable = true,
    bool isSelected = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    final type = item.type.toLowerCase();
    final name = item.name;
    final String identifier = _getMarkerLabel(name);

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

    Color fillColor;
    Color borderColor;
    Color textColor = cs.onSurface;
    final mutedFillColor = cs.onSurface.withValues(alpha: 0.06);
    final mutedBorderColor = cs.onSurface.withValues(alpha: 0.2);

    if (widget.availableFacilityNames != null) {
      // AI-selector mode
      if (isAvailable && isSelected) {
        fillColor = baseColor.withValues(alpha: 0.9);
        borderColor = baseColor;
        textColor = Colors.white;
      } else if (isAvailable) {
        fillColor = baseColor.withValues(alpha: 0.22);
        borderColor = baseColor;
        textColor = cs.onSurface;
      } else {
        fillColor = mutedFillColor;
        borderColor = mutedBorderColor;
        textColor = cs.onSurface;
      }
    } else if (widget.highlightFacilityId != null) {
      if (isHighlighted) {
        fillColor = baseColor.withValues(alpha: 0.9);
        borderColor = baseColor.withValues(alpha: 1.0);
        textColor = cs.onPrimary;
      } else {
        fillColor = mutedFillColor;
        borderColor = mutedBorderColor;
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
          if (icon != null && !isSelected)
            Opacity(
              opacity: isAvailable ? 0.2 : 0.2,
              child: Icon(
                icon,
                size: iconSize > 0 ? iconSize : 0,
                color: borderColor,
              ),
            ),

          // Room label
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: Text(
              identifier,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),

          if (isSelected)
            Positioned(
              top: 2,
              right: 2,
              child: Icon(Icons.check_circle, size: 10, color: Colors.white),
            ),
        ],
      ),
    );
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
