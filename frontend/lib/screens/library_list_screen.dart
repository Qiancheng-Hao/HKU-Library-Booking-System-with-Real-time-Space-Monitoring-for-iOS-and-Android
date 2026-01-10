import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/library_map_viewer.dart';
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
    showDialog(
      context: context,
      builder: (context) {
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

              SizedBox(
                height: 400,
                child: LibraryMapViewer(
                  facilities: items,
                  onFacilityTap: (item) {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BookingScreen(
                          facilityId: item['id'],
                          facilityName: item['name'],
                        ),
                      ),
                    );
                  },
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
