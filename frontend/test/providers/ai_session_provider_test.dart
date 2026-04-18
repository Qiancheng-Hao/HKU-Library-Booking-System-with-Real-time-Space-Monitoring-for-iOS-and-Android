import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/ai_models.dart';
import 'package:frontend/features/ai_agent/data/ai_agent_repository.dart';
import 'package:frontend/providers/ai_session_provider.dart';

import '../helpers/fake_api_client.dart';

void main() {
  group('AiSessionProvider', () {
    test('initSession creates a session and adds welcome message', () async {
      final repository = _FakeAiAgentRepository(sessionId: 'session-1');
      final provider = AiSessionProvider(aiAgentRepository: repository);

      await provider.initSession();

      expect(provider.hasSession, isTrue);
      expect(provider.sessionId, 'session-1');
      expect(provider.sessionError, isFalse);
      expect(provider.isLoading, isFalse);
      expect(provider.messages, hasLength(1));
      expect(provider.messages.single.isAi, isTrue);
      expect(provider.messages.single.text, contains('AI booking assistant'));
    });

    test('initSession captures session creation errors', () async {
      final repository = _FakeAiAgentRepository(
        createError: StateError('down'),
      );
      final provider = AiSessionProvider(aiAgentRepository: repository);

      await provider.initSession();

      expect(provider.hasSession, isFalse);
      expect(provider.sessionError, isTrue);
      expect(provider.isLoading, isFalse);
      expect(provider.messages, isEmpty);
    });

    test('sendMessage appends user message and AI reply', () async {
      final repository = _FakeAiAgentRepository(
        chatResponses: [
          const AiChatResponse(
            reply: 'I found rooms.',
            readyForConfirmation: false,
            suggestedOptions: AiSuggestedOptions(rooms: ['A1']),
          ),
        ],
      );
      final provider = AiSessionProvider(aiAgentRepository: repository);

      await provider.initSession();
      await provider.sendMessage('  find room  ');

      expect(repository.lastChatSessionId, 'session-1');
      expect(repository.lastChatMessage, 'find room');
      expect(provider.messages.map((m) => m.text), contains('find room'));
      expect(provider.messages.last.text, 'I found rooms.');
      expect(provider.messages.last.data?.suggestedOptions?.rooms, ['A1']);
      expect(provider.awaitingConfirmation, isFalse);
    });

    test(
      'sendMessage sets pending confirmation when preview is ready',
      () async {
        final repository = _FakeAiAgentRepository(
          chatResponses: [
            const AiChatResponse(
              reply: 'Ready to book.',
              readyForConfirmation: true,
              bookingPreview: AiBookingPreview(
                library: 'Main Library',
                date: '2026-04-16',
                candidateRooms: ['A1'],
              ),
            ),
          ],
        );
        final provider = AiSessionProvider(aiAgentRepository: repository);

        await provider.initSession();
        await provider.sendMessage('book it');

        expect(provider.awaitingConfirmation, isTrue);
        expect(provider.pendingConfirmation?.library, 'Main Library');
        expect(provider.pendingConfirmation?.candidateRooms, ['A1']);
      },
    );

    test('sendMessage appends fallback message on chat error', () async {
      final repository = _FakeAiAgentRepository(chatError: StateError('boom'));
      final provider = AiSessionProvider(aiAgentRepository: repository);

      await provider.initSession();
      await provider.sendMessage('hello');

      expect(provider.messages.last.text, contains('something went wrong'));
      expect(provider.isLoading, isFalse);
    });

    test('sendMessage marks recovered conversations with a divider', () async {
      final repository = _FakeAiAgentRepository(
        chatResponses: [
          const AiChatResponse(
            reply:
                'I had to reconnect the AI booking assistant. Please send your booking request again.',
            readyForConfirmation: false,
            warnings: [
              'The previous AI conversation was no longer available and has been restarted.',
            ],
          ),
        ],
      );
      final provider = AiSessionProvider(aiAgentRepository: repository);

      await provider.initSession();
      provider.awaitingConfirmation = true;
      provider.pendingConfirmation = const AiBookingPreview(
        library: 'Main Library',
        date: '2026-04-17',
      );
      await provider.sendMessage('hello');

      expect(
        provider.messages.any(
          (m) => m.isDivider && m.text == 'Conversation Reconnected',
        ),
        isTrue,
      );
      expect(provider.awaitingConfirmation, isFalse);
      expect(provider.pendingConfirmation, isNull);
      expect(provider.messages.last.text, contains('reconnect'));
    });

    test(
      'confirmBooking appends result, resets successful session, and starts new prompt',
      () async {
        final repository = _FakeAiAgentRepository(
          confirmResult: const AiBookingResult(
            summary: 'Booked A1.',
            success: true,
          ),
        );
        final provider = AiSessionProvider(aiAgentRepository: repository);

        await provider.initSession();
        await provider.confirmBooking(['A1']);

        expect(repository.lastConfirmSessionId, 'session-1');
        expect(repository.lastSelectedRooms, ['A1']);
        expect(repository.resetSessionIds, ['session-1']);
        expect(provider.awaitingConfirmation, isFalse);
        expect(provider.pendingConfirmation, isNull);
        expect(
          provider.messages.any((m) => m.isResult && m.text == 'Booked A1.'),
          isTrue,
        );
        expect(
          provider.messages.any((m) => m.isDivider && m.text == 'New Booking'),
          isTrue,
        );
        expect(provider.messages.last.text, contains('Start a new request'));
        expect(provider.isLoading, isFalse);
      },
    );

    test(
      'confirmBooking keeps chat history and blocks composer when new session recovery fails',
      () async {
        final repository = _FakeAiAgentRepository(
          sessionIds: ['session-1'],
          createSessionErrors: [null, StateError('down')],
          confirmResult: const AiBookingResult(
            summary: 'Booked A1.',
            success: true,
          ),
        );
        final provider = AiSessionProvider(aiAgentRepository: repository);

        await provider.initSession();
        await provider.confirmBooking(['A1']);

        expect(provider.hasSession, isFalse);
        expect(provider.sessionError, isFalse);
        expect(provider.composerStatusMessage, contains('refresh button'));
        expect(
          provider.messages.last.text,
          contains('could not start a new conversation'),
        );
      },
    );

    test(
      'confirmBooking does not reset session after failed booking result',
      () async {
        final repository = _FakeAiAgentRepository(
          confirmResult: const AiBookingResult(
            summary: 'No rooms booked.',
            success: false,
          ),
        );
        final provider = AiSessionProvider(aiAgentRepository: repository);

        await provider.initSession();
        await provider.confirmBooking(['A1']);

        expect(repository.resetSessionIds, isEmpty);
        expect(provider.messages.last.isResult, isTrue);
        expect(provider.messages.last.text, 'No rooms booked.');
      },
    );

    test('confirmBooking appends fallback message on confirm error', () async {
      final repository = _FakeAiAgentRepository(
        confirmError: StateError('confirm down'),
      );
      final provider = AiSessionProvider(aiAgentRepository: repository);

      await provider.initSession();
      await provider.confirmBooking(['A1']);

      expect(
        provider.messages.last.text,
        contains('Failed to confirm booking'),
      );
      expect(provider.isLoading, isFalse);
    });

    test('resetSession clears local state and starts a new session', () async {
      final repository = _FakeAiAgentRepository(sessionIds: ['old', 'new']);
      final provider = AiSessionProvider(aiAgentRepository: repository);

      await provider.initSession();
      provider.markSuggestionConsumed(provider.messages.single);
      await provider.resetSession();

      expect(repository.resetSessionIds, ['old']);
      expect(provider.sessionId, 'new');
      expect(provider.awaitingConfirmation, isFalse);
      expect(provider.pendingConfirmation, isNull);
      expect(provider.sessionError, isFalse);
      expect(provider.messages, hasLength(1));
    });

    test(
      'changeRoomSelection reopens room selection when earlier map options exist',
      () async {
        final repository = _FakeAiAgentRepository(
          chatResponses: [
            const AiChatResponse(
              reply: 'Pick on map.',
              readyForConfirmation: false,
              suggestedOptions: AiSuggestedOptions(rooms: ['A1', 'A2']),
              collectedInfo: AiCollectedInfo(
                roomTypeCode: '21',
                roomType: 'Discussion Room',
              ),
            ),
            const AiChatResponse(
              reply: 'Ready.',
              readyForConfirmation: true,
              bookingPreview: AiBookingPreview(
                library: 'Main Library',
                date: '2026-04-16',
                candidateRooms: ['A1'],
              ),
            ),
          ],
        );
        final provider = AiSessionProvider(aiAgentRepository: repository);

        await provider.initSession();
        await provider.sendMessage('show rooms');
        await provider.sendMessage('ready');
        provider.changeRoomSelection();

        expect(provider.awaitingConfirmation, isFalse);
        expect(provider.pendingConfirmation, isNull);
        expect(
          provider.messages.last.text,
          'Booking cancelled. Please choose another room from the map.',
        );
        expect(provider.messages.last.data?.readyForConfirmation, isFalse);
        expect(provider.messages.last.data?.suggestedOptions?.rooms, [
          'A1',
          'A2',
        ]);
        final reopenedMessage = provider.messages.last.data as AiChatResponse?;
        expect(reopenedMessage?.collectedInfo?.roomTypeCode, '21');
      },
    );

    test(
      'cancelConfirmation clears preview and appends cancellation message',
      () async {
        final repository = _FakeAiAgentRepository(
          chatResponses: [
            const AiChatResponse(
              reply: 'Ready.',
              readyForConfirmation: true,
              bookingPreview: AiBookingPreview(
                library: 'Main Library',
                date: '2026-04-16',
                candidateRooms: ['A1'],
              ),
            ),
          ],
        );
        final provider = AiSessionProvider(aiAgentRepository: repository);

        await provider.initSession();
        await provider.sendMessage('ready');
        provider.cancelConfirmation();

        expect(provider.awaitingConfirmation, isFalse);
        expect(provider.pendingConfirmation, isNull);
        expect(
          provider.messages.last.text,
          'Booking cancelled. How else can I help?',
        );
      },
    );

    test('changeTimeSelection prompts for a new time slot', () async {
      final repository = _FakeAiAgentRepository();
      final provider = AiSessionProvider(aiAgentRepository: repository);

      await provider.initSession();
      provider.awaitingConfirmation = true;
      provider.pendingConfirmation = const AiBookingPreview(
        library: 'Main Library',
        date: '2026-04-16',
        candidateRooms: ['A1'],
      );

      provider.changeTimeSelection();

      expect(provider.awaitingConfirmation, isFalse);
      expect(provider.pendingConfirmation, isNull);
      expect(
        provider.messages.last.text,
        'Booking paused. Send me your new time slot, for example 14:00-16:00.',
      );
    });

    test(
      'changeTimeSelection rewrites the next user message for the AI',
      () async {
        final repository = _FakeAiAgentRepository(
          chatResponses: [
            const AiChatResponse(
              reply: 'I found new rooms for that time.',
              readyForConfirmation: false,
            ),
          ],
        );
        final provider = AiSessionProvider(aiAgentRepository: repository);

        await provider.initSession();
        provider.changeTimeSelection();
        await provider.sendMessage('14:00-16:00');

        expect(repository.lastChatMessage, 'change time to 14:00-16:00');
        expect(provider.messages.last.text, 'I found new rooms for that time.');
      },
    );

    test(
      'unconsumed map suggestions expire when a new message is sent',
      () async {
        final repository = _FakeAiAgentRepository(
          chatResponses: [
            const AiChatResponse(
              reply: 'Pick on map.',
              readyForConfirmation: false,
              suggestedOptions: AiSuggestedOptions(rooms: ['A1']),
            ),
            const AiChatResponse(
              reply: 'Second reply.',
              readyForConfirmation: false,
            ),
          ],
        );
        final provider = AiSessionProvider(aiAgentRepository: repository);

        await provider.initSession();
        await provider.sendMessage('first');
        final suggestion = provider.messages.last;

        expect(provider.isSuggestionExpired(suggestion), isFalse);

        await provider.sendMessage('second');

        expect(provider.isSuggestionExpired(suggestion), isTrue);
      },
    );

    test(
      'consumed map suggestions do not expire when a new message is sent',
      () async {
        final repository = _FakeAiAgentRepository(
          chatResponses: [
            const AiChatResponse(
              reply: 'Pick on map.',
              readyForConfirmation: false,
              suggestedOptions: AiSuggestedOptions(rooms: ['A1']),
            ),
            const AiChatResponse(
              reply: 'Second reply.',
              readyForConfirmation: false,
            ),
          ],
        );
        final provider = AiSessionProvider(aiAgentRepository: repository);

        await provider.initSession();
        await provider.sendMessage('first');
        final suggestion = provider.messages.last;
        provider.markSuggestionConsumed(suggestion);

        await provider.sendMessage('second');

        expect(provider.isSuggestionConsumed(suggestion), isTrue);
        expect(provider.isSuggestionExpired(suggestion), isFalse);
      },
    );
  });
}

class _FakeAiAgentRepository extends AiAgentRepository {
  _FakeAiAgentRepository({
    String sessionId = 'session-1',
    List<String>? sessionIds,
    this.createError,
    List<Object?>? createSessionErrors,
    List<AiChatResponse>? chatResponses,
    this.chatError,
    AiBookingResult? confirmResult,
    this.confirmError,
  }) : sessionIds = sessionIds ?? [sessionId],
       createSessionErrors = createSessionErrors ?? [],
       chatResponses = chatResponses ?? [],
       confirmResult =
           confirmResult ??
           const AiBookingResult(summary: 'Booking processed.', success: true),
       super(FakeApiClient());

  final List<String> sessionIds;
  final Object? createError;
  final List<Object?> createSessionErrors;
  final List<AiChatResponse> chatResponses;
  final Object? chatError;
  final AiBookingResult confirmResult;
  final Object? confirmError;
  final List<String> resetSessionIds = [];

  String? lastChatSessionId;
  String? lastChatMessage;
  String? lastConfirmSessionId;
  List<String>? lastSelectedRooms;

  @override
  Future<String> createSession() async {
    if (createSessionErrors.isNotEmpty) {
      final queuedError = createSessionErrors.removeAt(0);
      if (queuedError != null) throw queuedError;
    }
    final currentError = createError;
    if (currentError != null) throw currentError;
    if (sessionIds.isEmpty) return 'session-1';
    return sessionIds.removeAt(0);
  }

  @override
  Future<AiChatResponse> chat({
    required String aiSessionId,
    required String message,
  }) async {
    final currentError = chatError;
    if (currentError != null) throw currentError;
    lastChatSessionId = aiSessionId;
    lastChatMessage = message;
    if (chatResponses.isEmpty) {
      return const AiChatResponse(
        reply: 'Default reply.',
        readyForConfirmation: false,
      );
    }
    return chatResponses.removeAt(0);
  }

  @override
  Future<AiBookingResult> confirmBooking({
    required String aiSessionId,
    required List<String> selectedRooms,
  }) async {
    final currentError = confirmError;
    if (currentError != null) throw currentError;
    lastConfirmSessionId = aiSessionId;
    lastSelectedRooms = selectedRooms;
    return confirmResult;
  }

  @override
  Future<void> resetSession(String aiSessionId) async {
    resetSessionIds.add(aiSessionId);
  }
}
