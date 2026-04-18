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

    test('getRealtimeOccupancy includes time when bypassing cache', () async {
      final client = FakeApiClient()
        ..postResponses['/api/v1/occupancy/occupancy'] = {'libraries': []};
      final repository = OccupancyRepository(client);
      final at = DateTime.utc(2026, 4, 18, 12, 34, 56);

      await repository.getRealtimeOccupancy(
        latitude: 22.1,
        longitude: 114.2,
        at: at,
      );

      expect(client.lastCall.body, {
        'latitude': 22.1,
        'longitude': 114.2,
        'radius': 50000000,
        'maxResults': 20,
        'time': '2026-04-18T12:34:56.000Z',
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

    test(
      'getRecommendation allows closest result without occupancy data',
      () async {
        final client = FakeApiClient()
          ..postResponses['/api/v1/occupancy/recommendation'] = {
            'libraryName': 'Main Library',
            'distanceFromUser': 100,
            'occupancyRate': null,
            'area': null,
          };
        final repository = OccupancyRepository(client);

        final recommendation = await repository.getRecommendation(
          latitude: 22.1,
          longitude: 114.2,
          strategy: 'distance',
        );

        expect(recommendation.libraryName, 'Main Library');
        expect(recommendation.area, isNull);
        expect(recommendation.occupancyRate, isNull);
        expect(recommendation.clampedOccupancyRate, isNull);
      },
    );

    test('getRecommendation includes time when bypassing cache', () async {
      final client = FakeApiClient()
        ..postResponses['/api/v1/occupancy/recommendation'] = {
          'libraryName': 'Main Library',
          'distanceFromUser': 100,
        };
      final repository = OccupancyRepository(client);
      final at = DateTime.utc(2026, 4, 18, 12, 34, 56);

      await repository.getRecommendation(
        latitude: 22.1,
        longitude: 114.2,
        strategy: 'distance',
        at: at,
      );

      expect(client.lastCall.body, {
        'latitude': 22.1,
        'longitude': 114.2,
        'strategy': 'distance',
        'time': '2026-04-18T12:34:56.000Z',
      });
    });
  });
}
