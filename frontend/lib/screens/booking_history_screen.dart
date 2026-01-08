import 'package:flutter/material.dart';
import '../services/api_service.dart';

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
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No reservations found.'));
                }

                final reservations = snapshot.data!;

                Widget buildList(List<String>? statusFilters) {
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
                    return Center(
                      child: Text(
                        statusFilters == null
                            ? "No reservations found."
                            : "No reservations found in this category.",
                      ),
                    );
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

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                    Text(
                                      'Status: $status',
                                      style: TextStyle(
                                        color: status == 'confirmed'
                                            ? Colors.green
                                            : Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
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
                                      child: const Text('Cancel'),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                }

                return TabBarView(
                  children: [
                    buildList(null),
                    buildList(['confirmed', 'pending']),
                    buildList(['finished', 'claimed', 'unclaimed']),
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
