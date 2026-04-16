import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/ai_agent/data/ai_agent_repository.dart';

import '../../../helpers/fake_api_client.dart';

void main() {
  group('AiAgentRepository', () {
    test('createSession posts to session endpoint', () async {
      final client = FakeApiClient()
        ..postResponses['/api/v1/ai/session'] = {'aiSessionId': 'session-1'};
      final repository = AiAgentRepository(client);

      final id = await repository.createSession();

      expect(id, 'session-1');
      expect(client.lastCall.path, '/api/v1/ai/session');
      expect(client.lastCall.successCodes, {201});
    });

    test('chat posts message and parses response', () async {
      final client = FakeApiClient()
        ..postResponses['/api/v1/ai/chat'] = {
          'reply': 'Choose one',
          'suggestedOptions': {
            'rooms': ['A1'],
          },
        };
      final repository = AiAgentRepository(client);

      final response = await repository.chat(
        aiSessionId: 'session-1',
        message: 'book a room',
      );

      expect(response.reply, 'Choose one');
      expect(response.suggestedOptions?.rooms, ['A1']);
      expect(client.lastCall.body, {
        'aiSessionId': 'session-1',
        'message': 'book a room',
      });
    });

    test('confirmBooking posts selected rooms and parses result', () async {
      final client = FakeApiClient()
        ..postResponses['/api/v1/ai/confirm'] = {
          'summary': 'Booked',
          'success': true,
        };
      final repository = AiAgentRepository(client);

      final result = await repository.confirmBooking(
        aiSessionId: 'session-1',
        selectedRooms: ['A1'],
      );

      expect(result.success, isTrue);
      expect(result.summary, 'Booked');
      expect(client.lastCall.body, {
        'aiSessionId': 'session-1',
        'selectedRooms': ['A1'],
        'confirm': true,
      });
    });

    test('resetSession posts session id', () async {
      final client = FakeApiClient();
      final repository = AiAgentRepository(client);

      await repository.resetSession('session-1');

      expect(client.lastCall.path, '/api/v1/ai/reset');
      expect(client.lastCall.body, {'aiSessionId': 'session-1'});
    });
  });
}
