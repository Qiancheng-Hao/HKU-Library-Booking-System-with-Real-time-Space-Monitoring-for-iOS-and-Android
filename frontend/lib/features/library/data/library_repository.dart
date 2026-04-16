import '../../../core/models/json_helpers.dart';
import '../../../core/models/library.dart';
import '../../../core/models/time_slot.dart';
import '../../../core/network/http_api_client.dart';

class LibraryRepository {
  final ApiClient _apiClient;

  LibraryRepository(this._apiClient);

  Future<List<Library>> getLibraries() async {
    final data = asJsonMap(await _apiClient.getJson('/api/v1/libraries'));
    return asJsonMapList(data['items']).map(Library.fromJson).toList();
  }

  Future<Library> getLibraryDetails(int id) async {
    final data = asJsonMap(await _apiClient.getJson('/api/v1/libraries/$id'));
    return Library.fromJson(asJsonMap(data['library']));
  }

  Future<List<TimeSlot>> getFacilityTimeSlots(
    int facilityId,
    String date,
  ) async {
    final data = asJsonMap(
      await _apiClient.getJson(
        '/api/v1/facilities/$facilityId/timeslots?date=$date',
      ),
    );
    return asJsonMapList(data['slots']).map(TimeSlot.fromJson).toList();
  }
}
