import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

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
        _selectedSlot = null; // Reset selection on date change
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

      await ApiService.createReservation(
        facilityId: widget.facilityId,
        date: dateStr,
        startTime: _selectedSlot!['start_time'],
        endTime: _selectedSlot!['end_time'],
      );

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking Confirmed!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // Go back to details
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
    final today = DateTime.now();
    final tomorrow = today.add(const Duration(days: 1));
    final isToday = _selectedDate.day == today.day;

    return Scaffold(
      appBar: AppBar(
        title: Text("Book ${widget.facilityName}"),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Date Selection
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.teal[50],
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
                const SizedBox(width: 16),
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

          // Time Slots Grid
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _slots.isEmpty
                ? const Center(child: Text("No slots available."))
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
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

                      final startTimeStr = slot['start_time'].toString();
                      final startTimeDisplay = startTimeStr.substring(0, 5);
                      final endTimeDisplay = slot['end_time']
                          .toString()
                          .substring(0, 5);

                      return InkWell(
                        onTap: isAvailable
                            ? () {
                                setState(() => _selectedSlot = slot);
                              }
                            : null,
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.blue
                                : isAvailable
                                ? Colors.green[100]
                                : Colors.grey[300],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.blue
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            "$startTimeDisplay - $endTimeDisplay",
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : isAvailable
                                  ? Colors.green[900]
                                  : Colors.grey[600],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Confirm Button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _selectedSlot != null ? _confirmBooking : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[300],
                ),
                child: const Text(
                  "Confirm Booking",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
