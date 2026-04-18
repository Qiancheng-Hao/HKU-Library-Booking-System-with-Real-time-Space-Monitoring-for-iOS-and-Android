import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../../../../core/models/occupancy.dart';
import '../../../../core/network/http_api_client.dart';
import '../../../../core/presentation/base_async_controller.dart';
import '../../data/occupancy_repository.dart';

class HomeController extends BaseAsyncController {
  final OccupancyRepository _occupancyRepository;

  HomeController({required OccupancyRepository occupancyRepository})
    : _occupancyRepository = occupancyRepository;

  Position? _currentPosition;
  String _recommendationStrategy = 'occupancyRate';
  OccupancySnapshot? _occupancy;
  LibraryOccupancy? _recommendation;
  bool _isRecommendationLoading = false;
  String? _recommendationErrorMessage;
  int _recommendationRequestId = 0;

  OccupancySnapshot? get occupancy => _occupancy;
  LibraryOccupancy? get recommendation => _recommendation;
  String get recommendationStrategy => _recommendationStrategy;
  bool get isRecommendationLoading => _isRecommendationLoading;
  String? get recommendationErrorMessage => _recommendationErrorMessage;

  Future<void> initialize() async {
    await refresh(bypassCache: false);
    await _getCurrentLocation();
    if (_currentPosition != null) {
      await refresh(bypassCache: false);
    }
  }

  Future<LibraryOccupancy> _fetchRecommendation({DateTime? at}) {
    return _occupancyRepository.getRecommendation(
      latitude: _currentPosition?.latitude,
      longitude: _currentPosition?.longitude,
      strategy: _recommendationStrategy,
      at: at,
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      _currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (_) {
      // Keep the default HKU recommendation path when location is unavailable.
    }
  }

  Future<void> refresh({bool bypassCache = true}) async {
    await runGuarded(() async {
      final requestTime = bypassCache ? DateTime.now() : null;
      final results = await Future.wait<Object>([
        _occupancyRepository.getRealtimeOccupancy(
          latitude: _currentPosition?.latitude,
          longitude: _currentPosition?.longitude,
          at: requestTime,
        ),
        _fetchRecommendation(at: requestTime),
      ]);
      _occupancy = results[0] as OccupancySnapshot;
      _recommendation = results[1] as LibraryOccupancy;
      _recommendationErrorMessage = null;
    });
  }

  void changeStrategy(String strategy) {
    if (_recommendationStrategy == strategy) return;
    _recommendationStrategy = strategy;
    notifyListeners();
    unawaited(_refreshRecommendation());
  }

  Future<void> _refreshRecommendation() async {
    final requestId = ++_recommendationRequestId;
    bool isLatestRequest() => requestId == _recommendationRequestId;
    final requestTime = DateTime.now();

    _isRecommendationLoading = true;
    _recommendationErrorMessage = null;
    notifyListeners();
    try {
      final recommendation = await _fetchRecommendation(at: requestTime);
      if (!isLatestRequest()) return;
      _recommendation = recommendation;
    } catch (e) {
      if (!isLatestRequest()) return;
      _recommendationErrorMessage = e is ApiException
          ? e.message
          : e.toString();
    } finally {
      if (isLatestRequest()) {
        _isRecommendationLoading = false;
        notifyListeners();
      }
    }
  }
}
