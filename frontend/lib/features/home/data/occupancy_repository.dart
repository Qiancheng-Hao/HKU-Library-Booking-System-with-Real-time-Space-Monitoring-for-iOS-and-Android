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
    DateTime? at,
  }) async {
    final lat = latitude ?? BackendConfig.defaultLatitude;
    final lon = longitude ?? BackendConfig.defaultLongitude;
    final body = <String, Object>{
      'latitude': lat,
      'longitude': lon,
      'radius': 50000000,
      'maxResults': 20,
    };
    if (at != null) {
      body['time'] = at.toUtc().toIso8601String();
    }

    final data = asJsonMap(
      await _apiClient.postJson('/api/v1/occupancy/occupancy', body: body),
    );
    return OccupancySnapshot.fromJson(data);
  }

  Future<LibraryOccupancy> getRecommendation({
    double? latitude,
    double? longitude,
    String strategy = 'occupancyRate',
    DateTime? at,
  }) async {
    final lat = latitude ?? BackendConfig.defaultLatitude;
    final lon = longitude ?? BackendConfig.defaultLongitude;
    final body = <String, Object>{
      'latitude': lat,
      'longitude': lon,
      'strategy': strategy,
    };
    if (at != null) {
      body['time'] = at.toUtc().toIso8601String();
    }

    final data = asJsonMap(
      await _apiClient.postJson('/api/v1/occupancy/recommendation', body: body),
    );
    return LibraryOccupancy.fromJson(data);
  }
}
