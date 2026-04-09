import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';

class BookingScreen extends StatefulWidget {
  final int facilityId;
  final String facilityName;

  const BookingScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  late DateTime _selectedDate;
  List<dynamic> _slots = [];
  bool _isLoading = true;
  Map<String, dynamic>? _selectedSlot;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _fetchSlots();
  }

  Future<void> _fetchSlots() async {
    setState(() => _isLoading = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final data = await ApiService.getFacilityTimeSlots(
        widget.facilityId,
        dateStr,
      );
      setState(() {
        _slots = data['slots'];
        _isLoading = false;
        _selectedSlot = null;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _confirmBooking() async {
    if (_selectedSlot == null) return;
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final reservation = await ApiService.createReservation(
        facilityId: widget.facilityId,
        date: dateStr,
        startTime: _selectedSlot!['start_time'],
        endTime: _selectedSlot!['end_time'],
      );
      await NotificationService.scheduleReservationReminder(reservation);
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Booking Confirmed!'),
            backgroundColor: AppColors.statusAvailable,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Booking Failed'),
            content: Text(e.toString()),
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
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final today = DateTime.now();
    final tomorrow = today.add(const Duration(days: 1));
    final isToday = _selectedDate.day == today.day;

    return Scaffold(
      appBar: AppBar(title: Text("Book ${widget.facilityName}")),
      body: Column(
        children: [
          // Date selection
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            color: cs.surfaceContainerLow,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text("Today"),
                  selected: isToday,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedDate = today);
                      _fetchSlots();
                    }
                  },
                ),
                const SizedBox(width: AppSpacing.lg),
                ChoiceChip(
                  label: const Text("Tomorrow"),
                  selected: !isToday,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedDate = tomorrow);
                      _fetchSlots();
                    }
                  },
                ),
              ],
            ),
          ),

          // Time slots grid
          Expanded(
            child: _isLoading
                ? const LoadingState(message: 'Loading available times...')
                : _slots.isEmpty
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
                    itemCount: _slots.length,
                    itemBuilder: (context, index) {
                      final slot = _slots[index];
                      final isAvailable = slot['status'] == 'available';
                      final isSelected = _selectedSlot == slot;

                      final startTimeDisplay = slot['start_time']
                          .toString()
                          .substring(0, 5);
                      final endTimeDisplay = slot['end_time']
                          .toString()
                          .substring(0, 5);

                      final Color bgColor;
                      final Color textColor;
                      if (isSelected) {
                        bgColor = cs.primary;
                        textColor = cs.onPrimary;
                      } else if (isAvailable) {
                        bgColor = AppColors.statusAvailable.withValues(
                          alpha: 0.28,
                        );
                        textColor = AppColors.statusAvailable;
                      } else {
                        bgColor = cs.surfaceContainerHighest.withValues(
                          alpha: 0.5,
                        );
                        textColor = cs.onSurfaceVariant;
                      }

                      final Border? borderOverlay;
                      if (isSelected) {
                        borderOverlay = Border.all(color: cs.primary, width: 2);
                      } else if (isAvailable) {
                        borderOverlay = Border.all(
                          color: AppColors.statusAvailable.withValues(
                            alpha: 0.55,
                          ),
                          width: 1,
                        );
                      } else {
                        borderOverlay = Border.all(
                          color: cs.outlineVariant,
                          width: 1,
                        );
                      }

                      return InkWell(
                        onTap: isAvailable
                            ? () => setState(() => _selectedSlot = slot)
                            : null,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: Container(
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: borderOverlay,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            "$startTimeDisplay\n$endTimeDisplay",
                            textAlign: TextAlign.center,
                            style: tt.labelSmall?.copyWith(
                              color: textColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Confirm button
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ElevatedButton(
              onPressed: _selectedSlot != null ? _confirmBooking : null,
              child: const Text("Confirm Booking"),
            ),
          ),
        ],
      ),
    );
  }
}
