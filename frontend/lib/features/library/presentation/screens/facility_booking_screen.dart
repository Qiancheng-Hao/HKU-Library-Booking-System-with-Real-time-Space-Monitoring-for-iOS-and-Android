import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../widgets/time_slot_cell.dart';
import '../../../../core/network/http_api_client.dart';
import '../../../../theme/app_theme.dart';
import '../../../../core/ui/widgets/empty_state.dart';
import '../../../../core/ui/widgets/loading_state.dart';
import '../../data/library_repository.dart';
import '../../data/reservation_repository.dart';
import '../controllers/booking_controller.dart';

class FacilityBookingScreen extends StatefulWidget {
  final int facilityId;
  final String facilityName;

  const FacilityBookingScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
  });

  @override
  State<FacilityBookingScreen> createState() => _FacilityBookingScreenState();
}

class _FacilityBookingScreenState extends State<FacilityBookingScreen> {
  late final BookingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = BookingController(
      libraryRepository: context.read<LibraryRepository>(),
      reservationRepository: context.read<ReservationRepository>(),
      facilityId: widget.facilityId,
    );
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _confirmBooking(BookingController controller) async {
    if (controller.selectedSlot == null) return;
    try {
      await controller.confirmBooking();
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking Confirmed!'),
          backgroundColor: AppColors.statusAvailable,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      final msg = e is ApiException
          ? e.message
          : 'Network error. Please check your connection.';
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Booking Failed'),
          content: Text(msg),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ChangeNotifierProvider<BookingController>.value(
      value: _controller,
      child: Consumer<BookingController>(
        builder: (context, controller, child) {
          final today = DateTime.now();
          final tomorrow = today.add(const Duration(days: 1));
          final isToday =
              controller.selectedDate.day == today.day &&
              controller.selectedDate.month == today.month &&
              controller.selectedDate.year == today.year;

          return Scaffold(
            appBar: AppBar(title: Text('Book ${widget.facilityName}')),
            body: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  color: cs.surfaceContainerLow,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ChoiceChip(
                        label: const Text('Today'),
                        selected: isToday,
                        onSelected: (selected) {
                          if (selected) controller.selectDate(today);
                        },
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      ChoiceChip(
                        label: const Text('Tomorrow'),
                        selected: !isToday,
                        onSelected: (selected) {
                          if (selected) controller.selectDate(tomorrow);
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: controller.isLoading
                      ? const LoadingState(
                          message: 'Loading available times...',
                        )
                      : controller.hasError
                      ? EmptyState(
                          icon: Icons.error_outline,
                          title: 'Could not load slots',
                          message: controller.errorMessage,
                          action: ElevatedButton(
                            onPressed: controller.fetchSlots,
                            child: const Text('Retry'),
                          ),
                        )
                      : controller.slots.isEmpty
                      ? const EmptyState(
                          icon: Icons.schedule_outlined,
                          title: 'No slots available',
                          message: 'Try a different date.',
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                childAspectRatio: 2.5,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                              ),
                          itemCount: controller.slots.length,
                          itemBuilder: (context, index) {
                            final slot = controller.slots[index];
                            return TimeSlotCell(
                              slot: slot,
                              isSelected: controller.selectedSlot == slot,
                              onTap: slot.isAvailable
                                  ? () => controller.selectSlot(slot)
                                  : null,
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: ElevatedButton(
                    onPressed:
                        controller.selectedSlot != null &&
                            !controller.isSubmitting
                        ? () => _confirmBooking(controller)
                        : null,
                    child: controller.isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Confirm Booking'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
