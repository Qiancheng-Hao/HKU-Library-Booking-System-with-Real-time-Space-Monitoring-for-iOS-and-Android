import '../../../core/config/backend_config.dart';
import '../../../core/models/json_helpers.dart';
import '../../../core/models/occupancy.dart';
import '../../../core/network/http_api_client.dart';

class OccupancyRepository {
  final ApiClient _apiClient;

  OccupancyRepository(this._apiClient);

  Future<OccupancySnapshot> getRealtimeOccupancy({
    double? latitude,
    double? longitude,
  }) async {
    final lat = latitude ?? BackendConfig.defaultLatitude;
    final lon = longitude ?? BackendConfig.defaultLongitude;

    final data = asJsonMap(
      await _apiClient.postJson(
        '/api/v1/occupancy/occupancy',
        body: {
          'latitude': lat,
          'longitude': lon,
          'radius': 50000000,
          'maxResults': 20,
        },
      ),
    );
    return OccupancySnapshot.fromJson(data);
  }

  Future<LibraryOccupancy> getRecommendation({
    double? latitude,
    double? longitude,
    String strategy = 'occupancyRate',
  }) async {
    final lat = latitude ?? BackendConfig.defaultLatitude;
    final lon = longitude ?? BackendConfig.defaultLongitude;

    final data = asJsonMap(
      await _apiClient.postJson(
        '/api/v1/occupancy/recommendation',
        body: {'latitude': lat, 'longitude': lon, 'strategy': strategy},
      ),
    );
    return LibraryOccupancy.fromJson(data);
  }
}
