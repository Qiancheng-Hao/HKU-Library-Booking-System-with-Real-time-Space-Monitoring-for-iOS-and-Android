import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'booking_screen.dart';
import 'booking_history_screen.dart';

class LibraryListScreen extends StatefulWidget {
  const LibraryListScreen({super.key});

  @override
  State<LibraryListScreen> createState() => _LibraryListScreenState();
}

class _LibraryListScreenState extends State<LibraryListScreen> {
  late Future<List<dynamic>> _librariesFuture;

  @override
  void initState() {
    super.initState();
    _librariesFuture = ApiService.getLibraries();
  }

  Future<void> _refreshLibraries() async {
    setState(() {
      _librariesFuture = ApiService.getLibraries();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: const TabBar(
              tabs: [
                Tab(text: "Book"),
                Tab(text: "My Reservations"),
              ],
              labelColor: Colors.teal,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.teal,
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [_buildLibraryList(), const BookingHistoryScreen()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLibraryList() {
    return Column(
      children: [
        // Header Row
        Container(
          width: double.infinity,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
          ),
          alignment: Alignment.center,
          child: const Text(
            "All Libraries",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.teal,
            ),
            textAlign: TextAlign.center,
          ),
        ),

        // List of Libraries
        Expanded(
          child: FutureBuilder<List<dynamic>>(
            future: _librariesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text('Error: ${snapshot.error}'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _refreshLibraries,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No libraries found.'));
              }

              final libraries = snapshot.data!;
              return RefreshIndicator(
                onRefresh: _refreshLibraries,
                child: ListView.builder(
                  itemCount: libraries.length,
                  itemBuilder: (context, index) {
                    final lib = libraries[index];
                    return LibraryListItem(library: lib);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class LibraryListItem extends StatefulWidget {
  final dynamic library;

  const LibraryListItem({super.key, required this.library});

  @override
  State<LibraryListItem> createState() => _LibraryListItemState();
}

class _LibraryListItemState extends State<LibraryListItem> {
  bool _isExpanded = false;
  Future<Map<String, dynamic>>? _detailsFuture;

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded && _detailsFuture == null) {
        _detailsFuture = ApiService.getLibraryDetails(widget.library['id']);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: _isExpanded ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: _isExpanded
            ? const BorderSide(color: Colors.teal, width: 2)
            : BorderSide.none,
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(
              Icons.local_library,
              color: Colors.teal,
              size: 36,
            ),
            title: Text(
              widget.library['name'] ?? 'Unknown Library',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(widget.library['campus'] ?? 'HKU Campus'),
            trailing: Icon(
              _isExpanded ? Icons.expand_less : Icons.expand_more,
              color: _isExpanded ? Colors.teal : Colors.grey,
            ),
            onTap: _toggleExpand,
          ),
          if (_isExpanded)
            FutureBuilder<Map<String, dynamic>>(
              future: _detailsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  );
                } else if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                } else if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No details available.'),
                  );
                }

                final library = snapshot.data!;
                final facilities = library['facilities'] as List<dynamic>;

                // Group facilities by Type
                final Map<String, List<dynamic>> groupedFacilities = {};
                for (var f in facilities) {
                  final type = f['type'] ?? 'Other';
                  if (!groupedFacilities.containsKey(type)) {
                    groupedFacilities[type] = [];
                  }
                  groupedFacilities[type]!.add(f);
                }

                final groupKeys = groupedFacilities.keys.toList();
                groupKeys.sort();

                if (groupKeys.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text("No facilities available."),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: groupKeys.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final type = groupKeys[index];
                    final items = groupedFacilities[type]!;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 4,
                      ),
                      leading: Icon(
                        _getFacilityIcon(type),
                        color: Colors.teal[300],
                        size: 24,
                      ),
                      title: Text(type),
                      trailing: Chip(
                        label: Text('${items.length}'),
                        backgroundColor: Colors.teal[50],
                        labelStyle: TextStyle(
                          color: Colors.teal[800],
                          fontSize: 12,
                        ),
                      ),
                      onTap: () {
                        _showFacilitySelectionDialog(
                          context,
                          type,
                          items,
                          library,
                        );
                      },
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }

  void _showFacilitySelectionDialog(
    BuildContext context,
    String type,
    List<dynamic> items,
    dynamic library,
  ) {
    const double aspectRatio = 1.0;

    // Extract unique floors and sort them
    final Set<int> floors = {};
    for (var item in items) {
      floors.add(item['floor'] as int? ?? 1);
    }
    final sortedFloors = floors.toList()..sort();

    // Default to the first floor (usually 1 or the lowest number)
    int selectedFloor = sortedFloors.isNotEmpty ? sortedFloors.first : 1;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Filter items by selected floor
            final displayedItems = items.where((item) {
              final itemFloor = item['floor'] as int? ?? 1;
              return itemFloor == selectedFloor;
            }).toList();

            return Dialog(
              insetPadding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Select $type",
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // Floor Selection (only if multiple floors exist)
                  if (sortedFloors.length > 1)
                    Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: sortedFloors.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final floor = sortedFloors[index];
                          final isSelected = floor == selectedFloor;
                          return ChoiceChip(
                            label: Text("Floor $floor"),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => selectedFloor = floor);
                              }
                            },
                            selectedColor: Colors.teal[100],
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? Colors.teal[900]
                                  : Colors.black,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          );
                        },
                      ),
                    ),

                  // Map Area
                  AspectRatio(
                    aspectRatio: aspectRatio,
                    child: Container(
                      color: Colors.grey[200],
                      child: ClipRect(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            // Calculate the boundaries of the map based on facilities
                            double mapBaseWidth = 100.0;
                            double mapBaseHeight = 100.0;

                            for (var item in displayedItems) {
                              final x = (item['x_coordinate'] ?? 0) as int;
                              final y = (item['y_coordinate'] ?? 0) as int;
                              final w = (item['width'] ?? 0) as int;
                              final h = (item['height'] ?? 0) as int;

                              // Update bounds if this item goes outside current bounds
                              if (x + w > mapBaseWidth) {
                                mapBaseWidth = (x + w).toDouble();
                              }
                              if (y + h > mapBaseHeight) {
                                mapBaseHeight = (y + h).toDouble();
                              }
                            }

                            // Add a small padding (e.g. 5%) to the bounds so items aren't glued to the edge
                            mapBaseWidth *= 1.05;
                            mapBaseHeight *= 1.05;

                            return InteractiveViewer(
                              minScale: 1.0,
                              maxScale: 4.0,
                              boundaryMargin: EdgeInsets.zero,
                              constrained: true,
                              child: SizedBox(
                                width: constraints.maxWidth,
                                height: constraints.maxHeight,
                                child: Stack(
                                  children: [
                                    // Placeholder Floor Plan
                                    Positioned.fill(
                                      child: CustomPaint(
                                        painter: GridPainter(),
                                        child: Container(
                                          color: Colors.white,
                                          child: Center(
                                            child: Icon(
                                              Icons.map_outlined,
                                              size: 100,
                                              color: Colors.teal.withValues(
                                                alpha: 0.05,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Facility Markers
                                    ...displayedItems.map((item) {
                                      final x =
                                          (item['x_coordinate'] ?? 50) as int;
                                      final y =
                                          (item['y_coordinate'] ?? 50) as int;

                                      final wPercent =
                                          (item['width'] ?? 0) as int;
                                      final hPercent =
                                          (item['height'] ?? 0) as int;

                                      // Scale coordinates to fit the calculated bounds
                                      final left =
                                          (x / mapBaseWidth) *
                                          constraints.maxWidth;
                                      final top =
                                          (y / mapBaseHeight) *
                                          constraints.maxHeight;

                                      // Scale dimensions similarly
                                      final double? pixelWidth = wPercent > 0
                                          ? (wPercent / mapBaseWidth) *
                                                constraints.maxWidth
                                          : null;
                                      final double? pixelHeight = hPercent > 0
                                          ? (hPercent / mapBaseHeight) *
                                                constraints.maxHeight
                                          : null;

                                      return Positioned(
                                        left: left,
                                        top: top,
                                        child: GestureDetector(
                                          onTap: () {
                                            Navigator.pop(context);
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    BookingScreen(
                                                      facilityId: item['id'],
                                                      facilityName:
                                                          item['name'],
                                                    ),
                                              ),
                                            );
                                          },
                                          child: _buildFacilityMarker(
                                            item,
                                            pixelWidth,
                                            pixelHeight,
                                          ),
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      "Tap a facility to book.",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFacilityMarker(
    dynamic item,
    double? pixelWidth,
    double? pixelHeight,
  ) {
    final type = (item['type'] as String? ?? '').toLowerCase();
    final name = item['name'] as String? ?? '';

    String identifier = name;
    final nameParts = name.split(' ');
    if (nameParts.length > 1) {
      identifier = nameParts.last;
    }

    // Default sizes based on type
    double defaultWidth = 30;
    double defaultHeight = 30;
    Color color = Colors.teal.withValues(alpha: 0.3);
    Color borderColor = Colors.teal;
    IconData? icon;

    if (type.contains('room')) {
      defaultWidth = 60;
      defaultHeight = 40;
      color = Colors.orange.withValues(alpha: 0.2);
      borderColor = Colors.orange;
      icon = Icons.groups;
    } else if (type.contains('desk') || type.contains('table')) {
      defaultWidth = 40;
      defaultHeight = 25;
      color = Colors.blue.withValues(alpha: 0.2);
      borderColor = Colors.blue;
      icon = Icons.table_restaurant;
    } else if (type.contains('booth')) {
      defaultWidth = 35;
      defaultHeight = 35;
      color = Colors.purple.withValues(alpha: 0.2);
      borderColor = Colors.purple;
      icon = Icons.chair;
    }

    // Use passed pixel dimensions if available, otherwise use defaults
    final double width = pixelWidth ?? defaultWidth;
    final double height = pixelHeight ?? defaultHeight;

    // Calculate icon size to fit within the smallest dimension of the box
    final double iconSize = (width < height ? width : height) - 4;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: borderColor, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (icon != null)
            Opacity(
              opacity: 0.2,
              child: Icon(
                icon,
                size: iconSize > 0 ? iconSize : 0,
                color: borderColor,
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: Text(
              identifier,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
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

  IconData _getFacilityIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'discussion room':
      case 'study room':
        return Icons.groups;
      case 'study table':
        return Icons.table_restaurant;
      case 'computer':
        return Icons.computer;
      default:
        return Icons.chair;
    }
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
