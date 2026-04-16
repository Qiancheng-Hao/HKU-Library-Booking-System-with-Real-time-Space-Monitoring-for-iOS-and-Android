import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/reservation.dart';
import 'package:frontend/features/library/data/reservation_repository.dart';

import '../../../helpers/fake_api_client.dart';

void main() {
  group('ReservationRepository', () {
    test(
      'createReservation posts booking payload and parses response',
      () async {
        final client = FakeApiClient()
          ..postResponses['/api/v1/reservations'] = {
            'id': 'abc',
            'reservation_date': '2026-04-16',
            'start_time': '09:00:00',
            'end_time': '10:00:00',
            'status': 'confirmed',
          };
        final repository = ReservationRepository(client);

        final reservation = await repository.createReservation(
          facilityId: 7,
          date: '2026-04-16',
          startTime: '09:00:00',
          endTime: '10:00:00',
        );

        expect(reservation.id, 'abc');
        expect(reservation.status, ReservationStatus.confirmed);
        expect(client.lastCall.method, 'POST');
        expect(client.lastCall.path, '/api/v1/reservations');
        expect(client.lastCall.successCodes, {201});
        expect(client.lastCall.body, {
          'facility_id': 7,
          'reservation_date': '2026-04-16',
          'start_time': '09:00:00',
          'end_time': '10:00:00',
          'notes': 'Mobile App Booking',
        });
      },
    );

    test('getUserReservations parses reservation list', () async {
      final client = FakeApiClient()
        ..getResponses['/api/v1/reservations/my'] = {
          'items': [
            {
              'id': 1,
              'reservation_date': '2026-04-16',
              'start_time': '11:00:00',
              'end_time': '12:00:00',
              'status': 'pending',
              'facility': {'id': 8, 'name': 'Study Table 1'},
            },
          ],
        };
      final repository = ReservationRepository(client);

      final reservations = await repository.getUserReservations();

      expect(reservations.single.id, '1');
      expect(reservations.single.status, ReservationStatus.pending);
      expect(reservations.single.facility?.name, 'Study Table 1');
    });

    test('cancelReservation deletes by id', () async {
      final client = FakeApiClient();
      final repository = ReservationRepository(client);

      await repository.cancelReservation('abc');

      expect(client.lastCall.method, 'DELETE');
      expect(client.lastCall.path, '/api/v1/reservations/abc');
    });
  });
}
