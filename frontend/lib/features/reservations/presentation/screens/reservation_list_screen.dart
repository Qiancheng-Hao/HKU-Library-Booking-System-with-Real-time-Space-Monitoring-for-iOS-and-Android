import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/models/reservation.dart';
import '../../../../core/ui/widgets/empty_state.dart';
import '../../../../core/ui/widgets/library_map_viewer.dart';
import '../../../../core/ui/widgets/loading_state.dart';
import '../../../../theme/app_theme.dart';
import '../../../library/data/library_repository.dart';
import '../../../library/data/reservation_repository.dart';
import '../controllers/reservation_list_controller.dart';
import '../widgets/reservation_list.dart';

class ReservationListScreen extends StatefulWidget {
  const ReservationListScreen({super.key});

  @override
  State<ReservationListScreen> createState() => _ReservationListScreenState();
}

class _ReservationListScreenState extends State<ReservationListScreen> {
  late final ReservationListController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ReservationListController(
      reservationRepository: context.read<ReservationRepository>(),
      libraryRepository: context.read<LibraryRepository>(),
    );
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _showMap(Reservation reservation) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final filteredFacilities = await _controller.loadFacilityMap(reservation);
      if (!mounted) return;
      Navigator.pop(context);

      final facility = reservation.facility;
      final facilityId = facility?.id;
      final targetType = facility?.type ?? 'Facility';
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
                              'Map: $targetType',
                              style: tt.labelMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              facility?.name ?? '',
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
                          child: Text('No facility map data available.'),
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
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not load map: $e')));
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

    if (confirm != true) return;

    try {
      await _controller.cancelReservation(reservationId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Reservation cancelled')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to cancel: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ChangeNotifierProvider<ReservationListController>.value(
      value: _controller,
      child: DefaultTabController(
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
              child: Consumer<ReservationListController>(
                builder: (context, controller, _) {
                  if (controller.isLoading && controller.reservations.isEmpty) {
                    return const LoadingState(
                      message: 'Loading reservations...',
                    );
                  }
                  if (controller.hasError && controller.reservations.isEmpty) {
                    return EmptyState(
                      icon: Icons.error_outline,
                      title: 'Could not load reservations',
                      message: controller.errorMessage,
                      action: ElevatedButton(
                        onPressed: controller.refresh,
                        child: const Text('Retry'),
                      ),
                    );
                  }

                  final reservations = controller.reservations;
                  return TabBarView(
                    children: [
                      ReservationList(
                        reservations: reservations,
                        emptyMessage: 'No reservations found.',
                        onRefresh: controller.refresh,
                        onViewMap: _showMap,
                        onCancel: _showCancelDialog,
                      ),
                      ReservationList(
                        reservations: reservations,
                        statusFilters: const [
                          ReservationStatus.confirmed,
                          ReservationStatus.pending,
                        ],
                        emptyMessage: 'No upcoming reservations.',
                        onRefresh: controller.refresh,
                        onViewMap: _showMap,
                        onCancel: _showCancelDialog,
                      ),
                      ReservationList(
                        reservations: reservations,
                        statusFilters: const [
                          ReservationStatus.finished,
                          ReservationStatus.claimed,
                          ReservationStatus.unclaimed,
                        ],
                        emptyMessage: 'No past reservations.',
                        onRefresh: controller.refresh,
                        onViewMap: _showMap,
                        onCancel: _showCancelDialog,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
