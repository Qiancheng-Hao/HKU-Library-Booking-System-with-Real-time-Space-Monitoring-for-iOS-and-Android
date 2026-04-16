import 'package:flutter/material.dart';
import '../../../../core/models/occupancy.dart';
import '../../../../core/ui/widgets/empty_state.dart';
import 'library_occupancy_tile.dart';

class LiveOccupancyList extends StatelessWidget {
  final OccupancySnapshot? snapshot;
  final bool isLoading;
  final String? errorMessage;

  const LiveOccupancyList({
    super.key,
    required this.snapshot,
    required this.isLoading,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading && snapshot == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (errorMessage != null && snapshot == null) {
      return EmptyState(
        icon: Icons.wifi_off_outlined,
        title: 'Could not load occupancy',
        message: errorMessage,
      );
    }
    if (snapshot == null || snapshot!.libraries.isEmpty) {
      return const EmptyState(
        icon: Icons.insights_outlined,
        title: 'No live data yet',
        message:
            "Real-time occupancy will appear here as soon as it's available.",
      );
    }

    final items = snapshot!.libraries;
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) => LibraryOccupancyTile(item: items[index]),
    );
  }
}
