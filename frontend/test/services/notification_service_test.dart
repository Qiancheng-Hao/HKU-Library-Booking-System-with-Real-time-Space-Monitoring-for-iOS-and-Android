import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/reservation.dart';
import 'package:frontend/services/notification_service.dart';

void main() {
  group('NotificationService pure logic', () {
    test('notificationIdFor uses hexadecimal suffix when possible', () {
      expect(
        NotificationService.notificationIdFor('00000000ffffffff'),
        0x7fffffff,
      );
    });

    test('notificationIdFor is stable for non-hex ids', () {
      final first = NotificationService.notificationIdFor('reservation-abc');
      final second = NotificationService.notificationIdFor('reservation-abc');

      expect(first, second);
      expect(first, greaterThanOrEqualTo(0));
    });

    test(
      'reminderScheduledAt returns reminder time for upcoming reservations',
      () {
        final reservation = _reservation(
          id: '1',
          status: 'confirmed',
          date: '2026-04-16',
          startTime: '10:00:00',
        );

        final scheduledAt = NotificationService.reminderScheduledAt(
          reservation,
          reminderMinutes: 30,
          now: DateTime(2026, 4, 16, 9),
        );

        expect(scheduledAt, DateTime(2026, 4, 16, 9, 30));
      },
    );

    test('reminderScheduledAt skips non-upcoming and past reminders', () {
      final finished = _reservation(
        id: '1',
        status: 'finished',
        date: '2026-04-16',
        startTime: '10:00:00',
      );
      final past = _reservation(
        id: '2',
        status: 'confirmed',
        date: '2026-04-16',
        startTime: '10:00:00',
      );

      expect(
        NotificationService.reminderScheduledAt(
          finished,
          reminderMinutes: 30,
          now: DateTime(2026, 4, 16, 9),
        ),
        isNull,
      );
      expect(
        NotificationService.reminderScheduledAt(
          past,
          reminderMinutes: 30,
          now: DateTime(2026, 4, 16, 9, 45),
        ),
        isNull,
      );
    });

    test('reminderBody includes facility, time, and library fallbacks', () {
      final reservation = _reservation(
        id: '1',
        status: 'confirmed',
        date: '2026-04-16',
        startTime: '10:00:00',
      );

      expect(
        NotificationService.reminderBody(reservation),
        'Reserved facility starts at 10:00 in HKU Library.',
      );
    });
  });
}

Reservation _reservation({
  required String id,
  required String status,
  required String date,
  required String startTime,
}) {
  return Reservation.fromJson({
    'id': id,
    'reservation_date': date,
    'start_time': startTime,
    'end_time': '11:00:00',
    'status': status,
  });
}
