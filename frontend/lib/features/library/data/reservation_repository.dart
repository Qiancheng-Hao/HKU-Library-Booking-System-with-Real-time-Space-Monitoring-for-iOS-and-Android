import '../../../core/models/json_helpers.dart';
import '../../../core/models/reservation.dart';
import '../../../core/network/http_api_client.dart';

class ReservationRepository {
  final ApiClient _apiClient;

  ReservationRepository(this._apiClient);

  Future<Reservation> createReservation({
    required int facilityId,
    required String date,
    required String startTime,
    required String endTime,
  }) async {
    final data = asJsonMap(
      await _apiClient.postJson(
        '/api/v1/reservations',
        successCodes: const {201},
        body: {
          'facility_id': facilityId,
          'reservation_date': date,
          'start_time': startTime,
          'end_time': endTime,
          'notes': 'Mobile App Booking',
        },
      ),
    );
    return Reservation.fromJson(data);
  }

  Future<List<Reservation>> getUserReservations() async {
    final data = asJsonMap(await _apiClient.getJson('/api/v1/reservations/my'));
    return asJsonMapList(data['items']).map(Reservation.fromJson).toList();
  }

  Future<void> cancelReservation(String reservationId) async {
    await _apiClient.delete('/api/v1/reservations/$reservationId');
  }
}
