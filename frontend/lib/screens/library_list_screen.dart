import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/library_map_viewer.dart';
import '../theme/app_theme.dart';
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
    setState(() => _librariesFuture = ApiService.getLibraries());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: cs.surfaceContainerLow,
            child: TabBar(
              tabs: const [
                Tab(text: "Book"),
                Tab(text: "My Reservations"),
              ],
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 44,
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            border: Border(bottom: BorderSide(color: cs.outlineVariant)),
          ),
          alignment: Alignment.center,
          child: Text(
            "All Libraries",
            style: tt.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: cs.primary,
            ),
          ),
        ),
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
                      Icon(Icons.error_outline, color: cs.error, size: 48),
                      const SizedBox(height: AppSpacing.lg),
                      Text('Error: ${snapshot.error}'),
                      const SizedBox(height: AppSpacing.lg),
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
                  padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm),
                  itemCount: libraries.length,
                  itemBuilder: (context, index) =>
                      LibraryListItem(library: libraries[index]),
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
        _detailsFuture =
            ApiService.getLibraryDetails(widget.library['id']);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: _isExpanded
              ? BorderSide(color: cs.primary, width: 1.5)
              : BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Column(
          children: [
            ListTile(
              leading: Icon(Icons.local_library,
                  color: cs.primary, size: 32),
              title: Text(
                widget.library['name'] ?? 'Unknown Library',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(widget.library['campus'] ?? 'HKU Campus'),
              trailing: Icon(
                _isExpanded ? Icons.expand_less : Icons.expand_more,
                color: _isExpanded ? cs.primary : cs.onSurfaceVariant,
              ),
              onTap: _toggleExpand,
            ),
            if (_isExpanded)
              FutureBuilder<Map<String, dynamic>>(
                future: _detailsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  } else if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Text('Error: ${snapshot.error}',
                          style: TextStyle(color: cs.error)),
                    );
                  } else if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: Text('No details available.'),
                    );
                  }

                  final library = snapshot.data!;
                  final facilities =
                      library['facilities'] as List<dynamic>;

                  final Map<String, List<dynamic>> grouped = {};
                  for (var f in facilities) {
                    final type = f['type'] ?? 'Other';
                    grouped.putIfAbsent(type, () => []).add(f);
                  }
                  final groupKeys = grouped.keys.toList()..sort();

                  if (groupKeys.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: Text("No facilities available."),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: groupKeys.length,
                    separatorBuilder: (_, separatorIndex) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final type = groupKeys[index];
                      final items = grouped[type]!;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xl,
                            vertical: AppSpacing.xs),
                        leading: Icon(_getFacilityIcon(type),
                            color: cs.secondary, size: 24),
                        title: Text(type),
                        trailing: Chip(
                          label: Text('${items.length}',
                              style: TextStyle(
                                  color: cs.onSecondaryContainer,
                                  fontSize: 12)),
                          backgroundColor: cs.secondaryContainer,
                          side: BorderSide.none,
                        ),
                        onTap: () => _showFacilitySelectionDialog(
                            context, type, items, library),
                      );
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showFacilitySelectionDialog(
    BuildContext context,
    String type,
    List<dynamic> items,
    dynamic library,
  ) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Text(type,
                        maxLines: 2,
                        overflow: TextOverflow.visible,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: cs.outlineVariant),
            SizedBox(
              height: 400,
              child: LibraryMapViewer(
                facilities: items,
                onFacilityTap: (item) {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BookingScreen(
                        facilityId: item['id'],
                        facilityName: item['name'],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text("Tap a facility to book.",
                  style: TextStyle(color: cs.onSurfaceVariant)),
            ),
          ],
        ),
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
