import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'booking_screen.dart';

class LibraryDetailScreen extends StatefulWidget {
  final int libraryId;
  final String libraryName;

  const LibraryDetailScreen({
    super.key,
    required this.libraryId,
    required this.libraryName,
  });

  @override
  State<LibraryDetailScreen> createState() => _LibraryDetailScreenState();
}

class _LibraryDetailScreenState extends State<LibraryDetailScreen> {
  late Future<Map<String, dynamic>> _libraryDetailFuture;

  @override
  void initState() {
    super.initState();
    _libraryDetailFuture = ApiService.getLibraryDetails(widget.libraryId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.libraryName),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _libraryDetailFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData) {
            return const Center(child: Text('No details found.'));
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

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Library Info Header
              Container(
                padding: const EdgeInsets.all(16.0),
                width: double.infinity,
                color: Colors.teal[50],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      library['name'],
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 16,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          library['location'] ?? 'Unknown Location',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  "Facilities",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),

              // Facilities List (Grouped by Type)
              Expanded(
                child: groupKeys.isEmpty
                    ? const Center(child: Text("No facilities available."))
                    : ListView.builder(
                        itemCount: groupKeys.length,
                        itemBuilder: (context, index) {
                          final type = groupKeys[index];
                          final items = groupedFacilities[type]!;

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            child: ListTile(
                              leading: Icon(
                                _getFacilityIcon(type),
                                color: Colors.teal,
                                size: 32,
                              ),
                              title: Text("$type"),
                              trailing: ElevatedButton(
                                onPressed: () {
                                  _showFacilitySelectionDialog(
                                    context,
                                    type,
                                    items,
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text("Select"),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showFacilitySelectionDialog(
    BuildContext context,
    String type,
    List<dynamic> items,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: Text("Select $type"),
          children: items.map((item) {
            return SimpleDialogOption(
              onPressed: () {
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
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(item['name'], style: const TextStyle(fontSize: 16)),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  IconData _getFacilityIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'room':
        return Icons.meeting_room;
      case 'desk':
        return Icons.desk;
      case 'computer':
        return Icons.computer;
      default:
        return Icons.chair;
    }
  }
}
