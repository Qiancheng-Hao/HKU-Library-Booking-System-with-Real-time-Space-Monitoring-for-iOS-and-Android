import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/reports/data/report_repository.dart';

import '../../../helpers/fake_api_client.dart';

void main() {
  group('ReportRepository', () {
    test('getSummary encodes location and parses response', () async {
      final client = FakeApiClient()
        ..getResponses['/api/v1/reports/summary?location=Chi+Wah+Learning+Commons&days=30'] =
            {
              'scope': {'location': 'Chi Wah Learning Commons', 'days': 30},
              'hasData': true,
              'averageOccupancyRate': 62.41,
              'peakOccupancyRate': 95.73,
              'totalSampleCount': 18420,
              'observationCount': 960,
            };
      final repository = ReportRepository(client);

      final summary = await repository.getSummary(
        location: 'Chi Wah Learning Commons',
      );

      expect(summary.scope.location, 'Chi Wah Learning Commons');
      expect(summary.averageOccupancyRate, 62.41);
      expect(
        client.lastCall.path,
        '/api/v1/reports/summary?location=Chi+Wah+Learning+Commons&days=30',
      );
    });

    test('getTrend passes bucket and days', () async {
      final client = FakeApiClient()
        ..getResponses['/api/v1/reports/trend?location=Main+Library&days=7&bucket=hour'] =
            {
              'scope': {'location': 'Main Library', 'days': 7},
              'bucket': 'hour',
              'points': [
                {
                  'bucketLabel': '2026-04-17 09:00',
                  'averageOccupancyRate': 40,
                  'peakOccupancyRate': 50,
                  'sampleCount': 10,
                },
              ],
            };
      final repository = ReportRepository(client);

      final trend = await repository.getTrend(location: 'Main Library');

      expect(trend.bucket, 'hour');
      expect(trend.points.single.averageOccupancyRate, 40);
      expect(
        client.lastCall.path,
        '/api/v1/reports/trend?location=Main+Library&days=7&bucket=hour',
      );
    });

    test('getHeatmap and getPeakHours parse collection payloads', () async {
      final client = FakeApiClient()
        ..getResponses['/api/v1/reports/heatmap?location=Main+Library&days=30'] =
            {
              'scope': {'location': 'Main Library', 'days': 30},
              'cells': [
                {
                  'weekdayIndex': 1,
                  'weekdayName': 'Monday',
                  'hour': 10,
                  'averageOccupancyRate': 48,
                  'peakOccupancyRate': 62,
                  'sampleCount': 188,
                },
              ],
            }
        ..getResponses['/api/v1/reports/peak-hours?location=Main+Library&days=30&limit=5'] =
            {
              'scope': {'location': 'Main Library', 'days': 30},
              'items': [
                {
                  'rank': 1,
                  'hour': 14,
                  'label': '14:00-15:00',
                  'averageOccupancyRate': 88,
                  'peakOccupancyRate': 97,
                  'sampleCount': 320,
                },
              ],
            };
      final repository = ReportRepository(client);

      final heatmap = await repository.getHeatmap(location: 'Main Library');
      final peakHours = await repository.getPeakHours(location: 'Main Library');

      expect(heatmap.cells.single.weekdayName, 'Monday');
      expect(peakHours.items.single.label, '14:00-15:00');
      expect(client.calls, hasLength(2));
    });
  });
}
