import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/reservation.dart';
import 'package:frontend/core/models/time_slot.dart';
import 'package:frontend/core/network/http_api_client.dart';
import 'package:frontend/features/library/data/library_repository.dart';
import 'package:frontend/features/library/data/reservation_repository.dart';
import 'package:frontend/features/library/presentation/controllers/booking_controller.dart';

void main() {
  group('BookingController', () {
    test('loads slots and clears selected slot on reload', () async {
      final slot = TimeSlot.fromJson({
        'start_time': '09:00:00',
        'end_time': '10:00:00',
        'status': 'available',
      });
      final repository = _FakeLibraryRepository(slots: [slot]);
      final controller = BookingController(
        libraryRepository: repository,
        reservationRepository: _FakeReservationRepository(),
        facilityId: 7,
      );

      await controller.initialize();
      controller.selectSlot(slot);

      expect(controller.slots, [slot]);
      expect(controller.selectedSlot, slot);

      await controller.fetchSlots();

      expect(controller.isLoading, isFalse);
      expect(controller.hasError, isFalse);
      expect(controller.slots, [slot]);
      expect(controller.selectedSlot, isNull);
      expect(repository.lastFacilityId, 7);
    });

    test('captures slot loading errors and keeps old slots', () async {
      final slot = TimeSlot.fromJson({
        'start_time': '09:00:00',
        'end_time': '10:00:00',
        'status': 'available',
      });
      final repository = _FakeLibraryRepository(slots: [slot]);
      final controller = BookingController(
        libraryRepository: repository,
        reservationRepository: _FakeReservationRepository(),
        facilityId: 7,
      );

      await controller.initialize();
      repository.error = StateError('slot service down');

      await controller.fetchSlots();

      expect(controller.hasError, isTrue);
      expect(controller.errorMessage, contains('slot service down'));
      expect(controller.slots, [slot]);
    });

    test(
      'creates reservation with selected slot and schedules reminder',
      () async {
        final slot = TimeSlot.fromJson({
          'start_time': '11:00:00',
          'end_time': '12:00:00',
          'status': 'available',
        });
        final reservation = Reservation.fromJson({
          'id': 'abc',
          'reservation_date': '2026-04-16',
          'start_time': '11:00:00',
          'end_time': '12:00:00',
          'status': 'confirmed',
        });
        final reservationRepository = _FakeReservationRepository(
          reservation: reservation,
        );
        Reservation? scheduledReservation;
        final controller = BookingController(
          libraryRepository: _FakeLibraryRepository(slots: [slot]),
          reservationRepository: reservationRepository,
          scheduleReservationReminder: (reservation) async {
            scheduledReservation = reservation;
          },
          facilityId: 7,
        );

        await controller.initialize();
        controller.selectSlot(slot);
        final result = await controller.confirmBooking();

        expect(result.id, 'abc');
        expect(scheduledReservation, result);
        expect(reservationRepository.createdFacilityId, 7);
        expect(reservationRepository.createdStartTime, '11:00:00');
        expect(reservationRepository.createdEndTime, '12:00:00');
        expect(controller.isSubmitting, isFalse);
      },
    );
  });
}

class _FakeLibraryRepository extends LibraryRepository {
  _FakeLibraryRepository({this.slots = const []}) : super(HttpApiClient());

  List<TimeSlot> slots;
  Object? error;
  int? lastFacilityId;

  @override
  Future<List<TimeSlot>> getFacilityTimeSlots(
    int facilityId,
    String date,
  ) async {
    final currentError = error;
    if (currentError != null) throw currentError;
    lastFacilityId = facilityId;
    return slots;
  }
}

class _FakeReservationRepository extends ReservationRepository {
  _FakeReservationRepository({Reservation? reservation})
    : reservation =
          reservation ??
          Reservation.fromJson({
            'id': '1',
            'reservation_date': '2026-04-16',
            'start_time': '09:00:00',
            'end_time': '10:00:00',
            'status': 'confirmed',
          }),
      super(HttpApiClient());

  final Reservation reservation;
  int? createdFacilityId;
  String? createdDate;
  String? createdStartTime;
  String? createdEndTime;

  @override
  Future<Reservation> createReservation({
    required int facilityId,
    required String date,
    required String startTime,
    required String endTime,
  }) async {
    createdFacilityId = facilityId;
    createdDate = date;
    createdStartTime = startTime;
    createdEndTime = endTime;
    return reservation;
  }
}
