import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/home/data/occupancy_repository.dart';

import '../../../helpers/fake_api_client.dart';

void main() {
  group('OccupancyRepository', () {
    test('getRealtimeOccupancy posts location and parses libraries', () async {
      final client = FakeApiClient()
        ..postResponses['/api/v1/occupancy/occupancy'] = {
          'libraries': [
            {'libraryName': 'Main Library', 'area': '2/F', 'occupancyRate': 42},
          ],
        };
      final repository = OccupancyRepository(client);

      final snapshot = await repository.getRealtimeOccupancy(
        latitude: 22.1,
        longitude: 114.2,
      );

      expect(snapshot.libraries.single.libraryName, 'Main Library');
      expect(client.lastCall.path, '/api/v1/occupancy/occupancy');
      expect(client.lastCall.body, {
        'latitude': 22.1,
        'longitude': 114.2,
        'radius': 50000000,
        'maxResults': 20,
      });
    });

    test(
      'getRecommendation posts strategy and parses recommendation',
      () async {
        final client = FakeApiClient()
          ..postResponses['/api/v1/occupancy/recommendation'] = {
            'libraryName': 'Main Library',
            'area': '2/F',
            'occupancyRate': '15',
            'distanceFromUser': 100,
          };
        final repository = OccupancyRepository(client);

        final recommendation = await repository.getRecommendation(
          latitude: 22.1,
          longitude: 114.2,
          strategy: 'distance',
        );

        expect(recommendation.libraryName, 'Main Library');
        expect(recommendation.clampedOccupancyRate, 15);
        expect(client.lastCall.path, '/api/v1/occupancy/recommendation');
        expect(client.lastCall.body, {
          'latitude': 22.1,
          'longitude': 114.2,
          'strategy': 'distance',
        });
      },
    );
  });
}
