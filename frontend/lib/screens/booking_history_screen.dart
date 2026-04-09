import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../widgets/library_map_viewer.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';

class BookingHistoryScreen extends StatefulWidget {
  const BookingHistoryScreen({super.key});

  @override
  State<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen> {
  late Future<List<dynamic>> _reservationsFuture;

  @override
  void initState() {
    super.initState();
    _reservationsFuture = ApiService.getUserReservations();
  }

  Future<void> _refresh() async {
    setState(() => _reservationsFuture = ApiService.getUserReservations());
  }

  Future<void> _showMap(dynamic reservation) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final facility = reservation['facility'];
      final libraryId = facility['library_id'];
      final facilityId = facility['id'];
      final targetType = facility['type'];

      if (libraryId == null) {
        throw Exception("Library ID missing in reservation details");
      }

      final libDetails = await ApiService.getLibraryDetails(libraryId);
      final allFacilities = libDetails['facilities'] as List<dynamic>;
      final filteredFacilities = allFacilities
          .where((f) => f['type'] == targetType)
          .toList();

      if (mounted) {
        Navigator.pop(context);
        final cs = Theme.of(context).colorScheme;
        final tt = Theme.of(context).textTheme;

        showDialog(
          context: context,
          builder: (context) => Dialog(
            insetPadding: const EdgeInsets.all(AppSpacing.lg),
            child: SizedBox(
              height: 500,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Map: $targetType",
                                style: tt.labelMedium?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                facility['name'],
                                style: tt.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: cs.outlineVariant),
                  Expanded(
                    child: filteredFacilities.isEmpty
                        ? const Center(
                            child: Text("No facility map data available."),
                          )
                        : LibraryMapViewer(
                            facilities: filteredFacilities,
                            highlightFacilityId: facilityId,
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Could not load map: $e")));
      }
    }
  }

  Future<void> _showCancelDialog(String reservationId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Reservation'),
        content: const Text(
          'Are you sure you want to cancel this reservation?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService.cancelReservation(reservationId);
        await NotificationService.cancelReservationReminder(reservationId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reservation cancelled')),
          );
          _refresh();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to cancel: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              border: Border(bottom: BorderSide(color: cs.outlineVariant)),
            ),
            child: const TabBar(
              tabs: [
                Tab(text: 'All'),
                Tab(text: 'Upcoming'),
                Tab(text: 'History'),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _reservationsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingState(message: 'Loading reservations...');
                } else if (snapshot.hasError) {
                  return EmptyState(
                    icon: Icons.error_outline,
                    title: 'Could not load reservations',
                    message: '${snapshot.error}',
                    action: ElevatedButton(
                      onPressed: _refresh,
                      child: const Text('Retry'),
                    ),
                  );
                }

                final reservations = snapshot.data ?? [];

                Widget buildList(
                  List<String>? statusFilters,
                  String emptyMessage,
                ) {
                  List<dynamic> filtered;
                  if (statusFilters == null) {
                    final upcoming = reservations
                        .where(
                          (r) => ['confirmed', 'pending'].contains(r['status']),
                        )
                        .toList();
                    final history = reservations
                        .where(
                          (r) =>
                              !['confirmed', 'pending'].contains(r['status']),
                        )
                        .toList();
                    filtered = [...upcoming, ...history];
                  } else {
                    filtered = reservations
                        .where((r) => statusFilters.contains(r['status']))
                        .toList();
                  }

                  if (filtered.isEmpty) {
                    return EmptyState(
                      icon: Icons.event_busy_outlined,
                      title: emptyMessage,
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final res = filtered[index];
                        final facility = res['facility'];
                        final date = res['reservation_date'];
                        final start = res['start_time'];
                        final end = res['end_time'];
                        final status = res['status'];
                        final isUpcoming = [
                          'confirmed',
                          'pending',
                        ].contains(status);

                        final Color statusColor;
                        if (status == 'confirmed') {
                          statusColor = AppColors.statusAvailable;
                        } else if (status == 'pending') {
                          statusColor = AppColors.statusModerate;
                        } else {
                          statusColor = cs.onSurfaceVariant;
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.sm,
                          ),
                          child: Card(
                            child: InkWell(
                              onTap: isUpcoming ? () => _showMap(res) : null,
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              child: Column(
                                children: [
                                  ListTile(
                                    leading: Icon(
                                      Icons.event_note,
                                      color: isUpcoming
                                          ? cs.primary
                                          : cs.onSurfaceVariant,
                                    ),
                                    title: Text(
                                      facility['name'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          facility['library_name'],
                                          style: TextStyle(
                                            color: cs.onSurface,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: AppSpacing.xs),
                                        Text(
                                          '$date | $start - $end',
                                          style: TextStyle(
                                            color: cs.onSurfaceVariant,
                                            fontSize: 13,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            Container(
                                              width: 8,
                                              height: 8,
                                              margin: const EdgeInsets.only(
                                                right: 6,
                                              ),
                                              decoration: BoxDecoration(
                                                color: statusColor,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            Text(
                                              status,
                                              style: TextStyle(
                                                color: statusColor,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                            if (isUpcoming) ...[
                                              const SizedBox(width: 8),
                                              Icon(
                                                Icons.map,
                                                size: 14,
                                                color: cs.secondary,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                "View Map",
                                                style: TextStyle(
                                                  color: cs.secondary,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (status == 'confirmed')
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: AppSpacing.sm,
                                      ),
                                      child: Center(
                                        child: TextButton(
                                          onPressed: () => _showCancelDialog(
                                            res['id'].toString(),
                                          ),
                                          style: TextButton.styleFrom(
                                            foregroundColor: cs.error,
                                          ),
                                          child: const Text(
                                            'Cancel Reservation',
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }

                return TabBarView(
                  children: [
                    buildList(null, "No reservations found."),
                    buildList([
                      'confirmed',
                      'pending',
                    ], "No upcoming reservations."),
                    buildList([
                      'finished',
                      'claimed',
                      'unclaimed',
                    ], "No past reservations."),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
