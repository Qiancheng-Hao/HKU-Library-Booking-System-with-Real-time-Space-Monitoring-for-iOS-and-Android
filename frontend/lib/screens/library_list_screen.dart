import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'library_detail_screen.dart';

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
    return Column(
      children: [
        // Header Row
        Container(
          padding: const EdgeInsets.all(16.0),
          width: double.infinity,
          color: Colors.grey[200],
          child: const Text(
            "ALL Libraries",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
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
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      elevation: 2,
                      child: ListTile(
                        leading: const Icon(
                          Icons.local_library,
                          color: Colors.teal,
                          size: 36,
                        ),
                        title: Text(
                          lib['name'] ?? 'Unknown Library',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(lib['location'] ?? 'No location info'),
                        trailing: Chip(
                          label: Text('${lib['facility_count']} Facilities'),
                          backgroundColor: Colors.teal[50],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LibraryDetailScreen(
                                libraryId: lib['id'],
                                libraryName: lib['name'],
                              ),
                            ),
                          );
                        },
                      ),
                    );
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
