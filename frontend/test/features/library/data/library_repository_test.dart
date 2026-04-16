import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/library/data/library_repository.dart';

import '../../../helpers/fake_api_client.dart';

void main() {
  group('LibraryRepository', () {
    test('getLibraries parses items into Library models', () async {
      final client = FakeApiClient()
        ..getResponses['/api/v1/libraries'] = {
          'items': [
            {'id': '1', 'name': 'Main Library', 'campus': 'HKU'},
          ],
        };
      final repository = LibraryRepository(client);

      final libraries = await repository.getLibraries();

      expect(libraries, hasLength(1));
      expect(libraries.single.id, 1);
      expect(libraries.single.name, 'Main Library');
      expect(client.lastCall.path, '/api/v1/libraries');
    });

    test('getLibraryDetails parses nested facilities', () async {
      final client = FakeApiClient()
        ..getResponses['/api/v1/libraries/3'] = {
          'library': {
            'id': 3,
            'name': 'Medical Library',
            'campus': 'Sassoon Road',
            'facilities': [
              {'id': '9', 'name': 'Discussion Room A1', 'floor': '2'},
            ],
          },
        };
      final repository = LibraryRepository(client);

      final library = await repository.getLibraryDetails(3);

      expect(library.id, 3);
      expect(library.facilities.single.id, 9);
      expect(library.facilities.single.floor, 2);
      expect(client.lastCall.path, '/api/v1/libraries/3');
    });

    test('getFacilityTimeSlots parses slots for the requested date', () async {
      final client = FakeApiClient()
        ..getResponses['/api/v1/facilities/9/timeslots?date=2026-04-16'] = {
          'slots': [
            {
              'start_time': '09:00:00',
              'end_time': '10:00:00',
              'status': 'available',
            },
          ],
        };
      final repository = LibraryRepository(client);

      final slots = await repository.getFacilityTimeSlots(9, '2026-04-16');

      expect(slots.single.isAvailable, isTrue);
      expect(slots.single.shortStartTime, '09:00');
      expect(
        client.lastCall.path,
        '/api/v1/facilities/9/timeslots?date=2026-04-16',
      );
    });
  });
}
