import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/library.dart';
import 'package:frontend/core/models/report.dart';
import 'package:frontend/core/network/http_api_client.dart';
import 'package:frontend/features/library/data/library_repository.dart';
import 'package:frontend/features/reports/data/report_repository.dart';
import 'package:frontend/features/reports/presentation/controllers/report_controller.dart';

void main() {
  group('ReportController', () {
    test(
      'loads libraries, selects the first library, and fetches dashboard',
      () async {
        final reports = _FakeReportRepository();
        final controller = ReportController(
          reportRepository: reports,
          libraryRepository: _FakeLibraryRepository(
            libraries: const [
              Library(id: 1, name: 'Main Library', campus: 'HKU'),
            ],
          ),
        );

        await controller.initialize();

        expect(controller.isLoading, isFalse);
        expect(controller.selectedLocation, 'Main Library');
        expect(controller.dashboard?.summary.hasData, isTrue);
        expect(reports.summaryLocations, ['Main Library']);
        expect(reports.trendBuckets, ['day']);
        expect(reports.trendDays, [7]);
      },
    );

    test('changing trend range only refreshes the trend report', () async {
      final reports = _FakeReportRepository();
      final controller = ReportController(
        reportRepository: reports,
        libraryRepository: _FakeLibraryRepository(
          libraries: const [
            Library(id: 1, name: 'Main Library', campus: 'HKU'),
          ],
        ),
      );
      await controller.initialize();

      await controller.selectTrendDays(1);

      expect(controller.trendDays, 1);
      expect(reports.summaryDays, [ReportController.reportSummaryDays]);
      expect(reports.trendDays, [7]);

      await Future<void>.delayed(
        ReportController.trendDebounceDuration +
            const Duration(milliseconds: 20),
      );

      expect(reports.trendDays, [7, 1]);
      expect(reports.trendBuckets.last, 'hour');
    });

    test(
      'debounces rapid trend range changes and keeps only the last one',
      () async {
        final reports = _FakeReportRepository();
        final controller = ReportController(
          reportRepository: reports,
          libraryRepository: _FakeLibraryRepository(
            libraries: const [
              Library(id: 1, name: 'Main Library', campus: 'HKU'),
            ],
          ),
        );
        await controller.initialize();

        await controller.selectTrendDays(1);
        await controller.selectTrendDays(30);

        expect(controller.trendDays, 30);
        expect(reports.trendDays, [7]);

        await Future<void>.delayed(
          ReportController.trendDebounceDuration +
              const Duration(milliseconds: 20),
        );

        expect(reports.trendDays, [7, 30]);
        expect(reports.trendBuckets.last, 'day');
      },
    );
  });
}

class _FakeLibraryRepository extends LibraryRepository {
  _FakeLibraryRepository({required this.libraries}) : super(HttpApiClient());

  final List<Library> libraries;

  @override
  Future<List<Library>> getLibraries() async => libraries;
}

class _FakeReportRepository extends ReportRepository {
  _FakeReportRepository() : super(HttpApiClient());

  final List<String?> summaryLocations = [];
  final List<int> summaryDays = [];
  final List<int> trendDays = [];
  final List<String> trendBuckets = [];

  @override
  Future<ReportSummary> getSummary({
    String? location,
    String? area,
    int days = 30,
  }) async {
    summaryLocations.add(location);
    summaryDays.add(days);
    return ReportSummary(
      scope: ReportScope(location: location, days: days),
      hasData: true,
      averageOccupancyRate: 40,
      peakOccupancyRate: 60,
      totalSampleCount: 10,
      observationCount: 2,
    );
  }

  @override
  Future<ReportTrend> getTrend({
    String? location,
    String? area,
    int days = 7,
    String bucket = 'hour',
  }) async {
    trendDays.add(days);
    trendBuckets.add(bucket);
    return ReportTrend(
      scope: ReportScope(location: location, days: days),
      bucket: bucket,
      points: const [],
    );
  }

  @override
  Future<ReportHeatmap> getHeatmap({
    String? location,
    String? area,
    int days = 30,
  }) async {
    return ReportHeatmap(
      scope: ReportScope(location: location, days: days),
      cells: const [],
    );
  }

  @override
  Future<ReportPeakHours> getPeakHours({
    String? location,
    String? area,
    int days = 30,
    int limit = 5,
  }) async {
    return ReportPeakHours(
      scope: ReportScope(location: location, days: days),
      items: const [],
    );
  }
}
