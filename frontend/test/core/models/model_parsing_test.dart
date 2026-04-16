import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/ai_models.dart';
import 'package:frontend/core/models/facility.dart';
import 'package:frontend/core/models/occupancy.dart';
import 'package:frontend/core/models/reservation.dart';
import 'package:frontend/core/models/time_slot.dart';

void main() {
  group('Facility.fromJson', () {
    test('coerces loose numeric and string fields', () {
      final facility = Facility.fromJson({
        'id': '42',
        'name': 'Discussion Room A1',
        'type': 'Discussion Room',
        'library_id': '7',
        'library_name': 'Main Library',
        'floor': '3',
        'room_no': 101,
        'facility_type_code': 'DISC',
        'x_coordinate': '12.5',
        'yCoordinate': 20,
        'width': '30',
        'height': 15.5,
      });

      expect(facility.id, 42);
      expect(facility.libraryId, 7);
      expect(facility.floor, 3);
      expect(facility.roomNo, '101');
      expect(facility.xCoordinate, 12.5);
      expect(facility.yCoordinate, 20);
      expect(facility.width, 30);
      expect(facility.height, 15.5);
      expect(facility.markerLabel, 'A1');
    });

    test('matches room by full name, room number, or marker label', () {
      final facility = Facility.fromJson({
        'id': 1,
        'name': 'Study Room CPD-3',
        'room_no': 'CPD-3',
      });

      expect(facility.matchesRoom(['study room cpd-3']), isTrue);
      expect(facility.matchesRoom(['CPD-3']), isTrue);
      expect(facility.matchesRoom(['cpd-3']), isTrue);
      expect(facility.matchesRoom(['CPD-4']), isFalse);
    });
  });

  group('Reservation.fromJson', () {
    test('parses nested facility and enum status', () {
      final reservation = Reservation.fromJson({
        'id': 123,
        'reservation_date': '2026-04-16',
        'start_time': '09:30:00',
        'end_time': '10:30:00',
        'status': 'CONFIRMED',
        'facility': {
          'id': '9',
          'name': 'Study Table 1',
          'library_name': 'Main Library',
        },
      });

      expect(reservation.id, '123');
      expect(reservation.status, ReservationStatus.confirmed);
      expect(reservation.statusText, 'confirmed');
      expect(reservation.isUpcoming, isTrue);
      expect(reservation.facility?.id, 9);
      expect(reservation.maybeStartDateTime, DateTime(2026, 4, 16, 9, 30));
      expect(reservation.shortStartTime, '09:30');
    });

    test('uses safe fallbacks for missing facility and invalid date', () {
      final reservation = Reservation.fromJson({
        'id': 'abc',
        'status': 'mystery',
        'startTime': 'bad',
      });

      expect(reservation.facility, isNull);
      expect(reservation.status, ReservationStatus.unknown);
      expect(reservation.isUpcoming, isFalse);
      expect(reservation.maybeStartDateTime, isNull);
    });
  });

  group('TimeSlot.fromJson', () {
    test('accepts alternative time keys and parses status enum', () {
      final slot = TimeSlot.fromJson({
        'start': '13:00:00',
        'end': '14:00:00',
        'status': 'AVAILABLE',
      });

      expect(slot.status, TimeSlotStatus.available);
      expect(slot.isAvailable, isTrue);
      expect(slot.shortStartTime, '13:00');
      expect(slot.shortEndTime, '14:00');
    });

    test('maps reserved slots to booked', () {
      final slot = TimeSlot.fromJson({'status': 'reserved'});

      expect(slot.status, TimeSlotStatus.booked);
      expect(slot.isAvailable, isFalse);
    });
  });

  group('Occupancy models', () {
    test('coerces occupancy and distance response shapes', () {
      final item = LibraryOccupancy.fromJson({
        'library_id': '5',
        'library_name': 'Chi Wah Learning Commons',
        'area': '1/F',
        'occupancy_rate': '72.5',
        'distance_from_user': '180.25',
      });

      expect(item.libraryId, 5);
      expect(item.displayLibraryName, 'Chi Wah Learning\nCommons');
      expect(item.clampedOccupancyRate, 72.5);
      expect(item.distanceFromUser, 180.25);
    });

    test('parses snapshot list and clamps display percentage', () {
      final snapshot = OccupancySnapshot.fromJson({
        'libraries': [
          {'libraryName': 'Main Library', 'occupancyRate': 120},
        ],
      });

      expect(snapshot.libraries, hasLength(1));
      expect(snapshot.libraries.single.clampedOccupancyRate, 100);
    });
  });

  group('AI models', () {
    test('parses partial chat response without optional payloads', () {
      final response = AiChatResponse.fromJson({'reply': 'Hello'});

      expect(response.reply, 'Hello');
      expect(response.readyForConfirmation, isFalse);
      expect(response.suggestedOptions, isNull);
      expect(response.bookingPreview, isNull);
    });

    test('parses suggested options, collected info, and preview', () {
      final response = AiChatResponse.fromJson({
        'reply': 'Pick a room',
        'readyForConfirmation': true,
        'suggestedOptions': {
          'locations': ['Main Library'],
          'room_types': ['Discussion Room'],
          'rooms': [101, '102'],
        },
        'collectedInfo': {
          'room_type_code': 'DISC',
          'room_type': 'Discussion Room',
        },
        'bookingPreview': {
          'library': 'Main Library',
          'date': '2026-04-16',
          'time_ranges': ['09:00-10:00'],
          'candidate_rooms': ['101'],
        },
      });

      expect(response.readyForConfirmation, isTrue);
      expect(response.suggestedOptions?.rooms, ['101', '102']);
      expect(response.collectedInfo?.roomTypeCode, 'DISC');
      expect(response.bookingPreview?.candidateRooms, ['101']);
    });

    test('parses failed reservation details', () {
      final result = AiBookingResult.fromJson({
        'summary': 'Some failed',
        'success': false,
        'failedReservations': [
          {'session': '09:00', 'room': '101', 'reason': 'Taken'},
        ],
      });

      expect(result.success, isFalse);
      expect(result.failedReservations.single.room, '101');
      expect(result.failedReservations.single.reason, 'Taken');
    });
  });
}
