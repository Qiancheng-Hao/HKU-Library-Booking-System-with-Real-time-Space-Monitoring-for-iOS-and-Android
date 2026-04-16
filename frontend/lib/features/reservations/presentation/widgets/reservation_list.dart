import 'package:flutter/material.dart';
import '../../../../core/models/reservation.dart';
import '../../../../core/ui/widgets/empty_state.dart';
import 'reservation_card.dart';

class ReservationList extends StatelessWidget {
  final List<Reservation> reservations;
  final List<ReservationStatus>? statusFilters;
  final String emptyMessage;
  final Future<void> Function() onRefresh;
  final Future<void> Function(Reservation) onViewMap;
  final Future<void> Function(String) onCancel;

  const ReservationList({
    super.key,
    required this.reservations,
    this.statusFilters,
    required this.emptyMessage,
    required this.onRefresh,
    required this.onViewMap,
    required this.onCancel,
  });

  List<Reservation> _filtered() {
    if (statusFilters == null) {
      final upcoming = reservations.where((r) => r.isUpcoming).toList();
      final history = reservations.where((r) => !r.isUpcoming).toList();
      return [...upcoming, ...history];
    }
    return reservations
        .where((r) => statusFilters!.contains(r.status))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered();

    if (filtered.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: 320,
              child: EmptyState(
                icon: Icons.event_busy_outlined,
                title: emptyMessage,
                message: 'Pull down to refresh or try again now.',
                action: ElevatedButton(
                  onPressed: onRefresh,
                  child: const Text('Retry'),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: filtered.length,
        itemBuilder: (context, index) => ReservationCard(
          res: filtered[index],
          onViewMap: onViewMap,
          onCancel: onCancel,
        ),
      ),
    );
  }
}
