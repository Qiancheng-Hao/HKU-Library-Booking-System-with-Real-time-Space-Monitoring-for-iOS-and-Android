import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/library_map_viewer.dart';

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
    setState(() {
      _reservationsFuture = ApiService.getUserReservations();
    });
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

        showDialog(
          context: context,
          builder: (context) => Dialog(
            insetPadding: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: SizedBox(
              height: 500,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Map: $targetType",
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                facility['name'],
                                style: const TextStyle(
                                  fontSize: 18,
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
                  const Divider(height: 1),
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
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: const TabBar(
              tabs: [
                Tab(text: 'All'),
                Tab(text: 'Upcoming'),
                Tab(text: 'History'),
              ],
              indicatorColor: Colors.teal,
              indicatorSize: TabBarIndicatorSize.label,
              labelColor: Colors.teal,
              labelStyle: TextStyle(fontWeight: FontWeight.bold),
              unselectedLabelColor: Colors.grey,
            ),
          ),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _reservationsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
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
                    return Center(child: Text(emptyMessage));
                  }

                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView.builder(
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

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          elevation: isUpcoming ? 4 : 1,
                          child: InkWell(
                            onTap: isUpcoming ? () => _showMap(res) : null,
                            borderRadius: BorderRadius.circular(12),
                            child: Column(
                              children: [
                                ListTile(
                                  leading: Icon(
                                    Icons.event_note,
                                    color: status == 'confirmed'
                                        ? Colors.teal
                                        : Colors.grey,
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
                                      if (facility != null)
                                        Text(
                                          facility['library_name'],
                                          style: const TextStyle(
                                            color: Colors.black87,
                                            fontSize: 14,
                                          ),
                                        ),
                                      const SizedBox(height: 4),
                                      Text('$date | $start - $end'),
                                      Row(
                                        children: [
                                          Text(
                                            'Status: $status',
                                            style: TextStyle(
                                              color: status == 'confirmed'
                                                  ? Colors.green
                                                  : Colors.red,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          if (isUpcoming) ...[
                                            const SizedBox(width: 8),
                                            const Icon(
                                              Icons.map,
                                              size: 16,
                                              color: Colors.blue,
                                            ),
                                            const SizedBox(width: 4),
                                            const Text(
                                              "View Map",
                                              style: TextStyle(
                                                color: Colors.blue,
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
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Center(
                                      child: TextButton(
                                        onPressed: () => _showCancelDialog(
                                          res['id'].toString(),
                                        ),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.red,
                                        ),
                                        child: const Text('Cancel Reservation'),
                                      ),
                                    ),
                                  ),
                              ],
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
