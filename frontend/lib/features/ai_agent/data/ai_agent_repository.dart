import '../../../core/models/ai_models.dart';
import '../../../core/models/json_helpers.dart';
import '../../../core/network/http_api_client.dart';

class AiAgentRepository {
  final ApiClient _apiClient;

  AiAgentRepository(this._apiClient);

  Future<String> createSession() async {
    final data = asJsonMap(
      await _apiClient.postJson(
        '/api/v1/ai/session',
        successCodes: const {201},
      ),
    );
    return readString(data, 'aiSessionId');
  }

  Future<AiChatResponse> chat({
    required String aiSessionId,
    required String message,
  }) async {
    final data = asJsonMap(
      await _apiClient.postJson(
        '/api/v1/ai/chat',
        body: {'aiSessionId': aiSessionId, 'message': message},
      ),
    );
    return AiChatResponse.fromJson(data);
  }

  Future<AiBookingResult> confirmBooking({
    required String aiSessionId,
    required List<String> selectedRooms,
  }) async {
    final data = asJsonMap(
      await _apiClient.postJson(
        '/api/v1/ai/confirm',
        body: {
          'aiSessionId': aiSessionId,
          'selectedRooms': selectedRooms,
          'confirm': true,
        },
      ),
    );
    return AiBookingResult.fromJson(data);
  }

  Future<void> resetSession(String aiSessionId) async {
    await _apiClient.postJson(
      '/api/v1/ai/reset',
      body: {'aiSessionId': aiSessionId},
    );
  }
}
