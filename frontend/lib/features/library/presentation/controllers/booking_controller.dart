import 'package:intl/intl.dart';

import '../../../../core/models/reservation.dart';
import '../../../../core/models/time_slot.dart';
import '../../../../core/presentation/base_async_controller.dart';
import '../../../../services/notification_service.dart';
import '../../data/library_repository.dart';
import '../../data/reservation_repository.dart';

typedef ReservationReminderScheduler =
    Future<void> Function(Reservation reservation);

class BookingController extends BaseAsyncController {
  final LibraryRepository _libraryRepository;
  final ReservationRepository _reservationRepository;
  final ReservationReminderScheduler _scheduleReservationReminder;
  final int facilityId;

  BookingController({
    required LibraryRepository libraryRepository,
    required ReservationRepository reservationRepository,
    ReservationReminderScheduler? scheduleReservationReminder,
    required this.facilityId,
  }) : _libraryRepository = libraryRepository,
       _reservationRepository = reservationRepository,
       _scheduleReservationReminder =
           scheduleReservationReminder ??
           NotificationService.scheduleReservationReminder;

  late DateTime _selectedDate;
  List<TimeSlot> _slots = [];
  bool _isSubmitting = false;
  TimeSlot? _selectedSlot;

  DateTime get selectedDate => _selectedDate;
  List<TimeSlot> get slots => _slots;
  bool get isSubmitting => _isSubmitting;
  TimeSlot? get selectedSlot => _selectedSlot;

  Future<void> initialize() async {
    _selectedDate = DateTime.now();
    await fetchSlots();
  }

  Future<void> fetchSlots() async {
    await runGuarded(() async {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      _slots = await _libraryRepository.getFacilityTimeSlots(
        facilityId,
        dateStr,
      );
      _selectedSlot = null;
    });
  }

  Future<void> selectDate(DateTime date) async {
    _selectedDate = date;
    notifyListeners();
    await fetchSlots();
  }

  void selectSlot(TimeSlot? slot) {
    _selectedSlot = slot;
    notifyListeners();
  }

  Future<Reservation> confirmBooking() async {
    if (_selectedSlot == null || _isSubmitting) {
      throw StateError('Please select a slot first.');
    }

    _isSubmitting = true;
    notifyListeners();
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final reservation = await _reservationRepository.createReservation(
        facilityId: facilityId,
        date: dateStr,
        startTime: _selectedSlot!.startTime,
        endTime: _selectedSlot!.endTime,
      );
      await _scheduleReservationReminder(reservation);
      return reservation;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
