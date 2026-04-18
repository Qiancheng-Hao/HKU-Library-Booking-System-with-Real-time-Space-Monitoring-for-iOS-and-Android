import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/occupancy.dart';
import 'package:frontend/core/network/http_api_client.dart';
import 'package:frontend/features/home/data/occupancy_repository.dart';
import 'package:frontend/features/home/presentation/controllers/home_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HomeController', () {
    test('refresh loads occupancy and recommendation', () async {
      final repository = _FakeOccupancyRepository();
      final controller = HomeController(occupancyRepository: repository);

      await controller.refresh();

      expect(controller.isLoading, isFalse);
      expect(controller.hasError, isFalse);
      expect(
        controller.occupancy?.libraries.single.libraryName,
        'Main Library',
      );
      expect(controller.recommendation?.libraryName, 'Main Library');
      expect(repository.lastStrategy, 'occupancyRate');
      expect(repository.lastOccupancyAt, isNotNull);
      expect(repository.lastRecommendationAt, isNotNull);
    });

    test('refresh captures errors and keeps previous data', () async {
      final repository = _FakeOccupancyRepository();
      final controller = HomeController(occupancyRepository: repository);

      await controller.refresh();
      repository.error = StateError('occupancy offline');

      await controller.refresh();

      expect(controller.hasError, isTrue);
      expect(controller.errorMessage, contains('occupancy offline'));
      expect(
        controller.occupancy?.libraries.single.libraryName,
        'Main Library',
      );
      expect(controller.recommendation?.libraryName, 'Main Library');
    });

    test('changeStrategy refreshes recommendation only', () async {
      final repository = _FakeOccupancyRepository();
      final controller = HomeController(occupancyRepository: repository);

      await controller.refresh();
      repository.recommendation = const LibraryOccupancy(
        libraryName: 'Chi Wah Learning Commons',
        area: '1/F',
        occupancyRate: 20,
        distanceFromUser: 80,
      );

      controller.changeStrategy('distance');
      expect(controller.recommendationStrategy, 'distance');
      expect(controller.isRecommendationLoading, isTrue);

      await pumpEventQueue();

      expect(controller.isRecommendationLoading, isFalse);
      expect(
        controller.recommendation?.libraryName,
        'Chi Wah Learning Commons',
      );
      expect(
        controller.occupancy?.libraries.single.libraryName,
        'Main Library',
      );
      expect(repository.lastStrategy, 'distance');
      expect(repository.lastOccupancyAt, isNotNull);
      expect(repository.lastRecommendationAt, isNotNull);
    });

    test('initialize keeps cached startup requests cache-friendly', () async {
      final repository = _FakeOccupancyRepository();
      final controller = HomeController(occupancyRepository: repository);

      await controller.initialize();

      expect(repository.occupancyRequestTimes.first, isNull);
      expect(repository.recommendationRequestTimes.first, isNull);
    });
  });
}

class _FakeOccupancyRepository extends OccupancyRepository {
  _FakeOccupancyRepository() : super(HttpApiClient());

  OccupancySnapshot occupancy = const OccupancySnapshot(
    libraries: [
      LibraryOccupancy(
        libraryName: 'Main Library',
        area: '2/F',
        occupancyRate: 40,
        distanceFromUser: 120,
      ),
    ],
  );
  LibraryOccupancy recommendation = const LibraryOccupancy(
    libraryName: 'Main Library',
    area: '2/F',
    occupancyRate: 40,
    distanceFromUser: 120,
  );
  Object? error;
  String? lastStrategy;
  DateTime? lastOccupancyAt;
  DateTime? lastRecommendationAt;
  final List<DateTime?> occupancyRequestTimes = [];
  final List<DateTime?> recommendationRequestTimes = [];

  @override
  Future<OccupancySnapshot> getRealtimeOccupancy({
    double? latitude,
    double? longitude,
    DateTime? at,
  }) async {
    final currentError = error;
    if (currentError != null) throw currentError;
    lastOccupancyAt = at;
    occupancyRequestTimes.add(at);
    return occupancy;
  }

  @override
  Future<LibraryOccupancy> getRecommendation({
    double? latitude,
    double? longitude,
    String strategy = 'distance',
    DateTime? at,
  }) async {
    final currentError = error;
    if (currentError != null) throw currentError;
    lastStrategy = strategy;
    lastRecommendationAt = at;
    recommendationRequestTimes.add(at);
    return recommendation;
  }
}
