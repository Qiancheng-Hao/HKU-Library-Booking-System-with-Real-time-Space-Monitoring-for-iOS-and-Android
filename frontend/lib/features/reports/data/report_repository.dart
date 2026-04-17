import '../../../core/models/json_helpers.dart';
import '../../../core/models/report.dart';
import '../../../core/network/http_api_client.dart';

class ReportRepository {
  final ApiClient _apiClient;

  ReportRepository(this._apiClient);

  Future<ReportSummary> getSummary({
    String? location,
    String? area,
    int days = 30,
  }) async {
    final data = asJsonMap(
      await _apiClient.getJson(
        _reportPath('/api/v1/reports/summary', {
          'location': location,
          'area': area,
          'days': days.toString(),
        }),
      ),
    );
    return ReportSummary.fromJson(data);
  }

  Future<ReportTrend> getTrend({
    String? location,
    String? area,
    int days = 7,
    String bucket = 'hour',
  }) async {
    final data = asJsonMap(
      await _apiClient.getJson(
        _reportPath('/api/v1/reports/trend', {
          'location': location,
          'area': area,
          'days': days.toString(),
          'bucket': bucket,
        }),
      ),
    );
    return ReportTrend.fromJson(data);
  }

  Future<ReportHeatmap> getHeatmap({
    String? location,
    String? area,
    int days = 30,
  }) async {
    final data = asJsonMap(
      await _apiClient.getJson(
        _reportPath('/api/v1/reports/heatmap', {
          'location': location,
          'area': area,
          'days': days.toString(),
        }),
      ),
    );
    return ReportHeatmap.fromJson(data);
  }

  Future<ReportPeakHours> getPeakHours({
    String? location,
    String? area,
    int days = 30,
    int limit = 5,
  }) async {
    final data = asJsonMap(
      await _apiClient.getJson(
        _reportPath('/api/v1/reports/peak-hours', {
          'location': location,
          'area': area,
          'days': days.toString(),
          'limit': limit.toString(),
        }),
      ),
    );
    return ReportPeakHours.fromJson(data);
  }

  String _reportPath(String path, Map<String, String?> query) {
    final filtered = <String, String>{};
    for (final entry in query.entries) {
      final value = entry.value;
      if (value == null || value.trim().isEmpty) continue;
      filtered[entry.key] = value;
    }
    return Uri(path: path, queryParameters: filtered).toString();
  }
}
