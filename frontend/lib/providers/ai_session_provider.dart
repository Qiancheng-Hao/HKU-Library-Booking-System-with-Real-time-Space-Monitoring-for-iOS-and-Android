import 'package:flutter/material.dart';

import '../core/models/ai_models.dart';
import '../features/ai_agent/data/ai_agent_repository.dart';

enum _MessageType { user, ai, result, divider }

class ChatMessage {
  final String text;
  final _MessageType _type;
  final AiMessageData? data;

  ChatMessage._({required this.text, required _MessageType type, this.data})
    : _type = type;

  factory ChatMessage.user(String text) =>
      ChatMessage._(text: text, type: _MessageType.user);

  factory ChatMessage.ai(String text, {AiMessageData? data}) =>
      ChatMessage._(text: text, type: _MessageType.ai, data: data);

  factory ChatMessage.result(String text, {AiMessageData? data}) =>
      ChatMessage._(text: text, type: _MessageType.result, data: data);

  factory ChatMessage.divider(String text) =>
      ChatMessage._(text: text, type: _MessageType.divider);

  bool get isUser => _type == _MessageType.user;
  bool get isResult => _type == _MessageType.result;
  bool get isAi => _type == _MessageType.ai;
  bool get isDivider => _type == _MessageType.divider;
}

class AiSessionProvider extends ChangeNotifier {
  final AiAgentRepository _aiAgentRepository;
  final List<ChatMessage> messages = [];
  static const _welcomeText =
      "Hi! I'm your AI booking assistant. Tell me what you need — "
      'for example: "Book a study room at Main Library tomorrow afternoon."';

  String? _sessionId;
  bool isLoading = false;
  bool sessionError = false;
  bool awaitingConfirmation = false;
  AiBookingPreview? pendingConfirmation;
  String? _composerStatusMessage;

  final Set<ChatMessage> _consumedMapSuggestions = {};
  final Set<ChatMessage> _expiredMapSuggestions = {};

  String? get sessionId => _sessionId;
  bool get hasSession => _sessionId != null;
  String? get composerStatusMessage => _composerStatusMessage;

  bool isSuggestionConsumed(ChatMessage msg) =>
      _consumedMapSuggestions.contains(msg);
  bool isSuggestionExpired(ChatMessage msg) =>
      _expiredMapSuggestions.contains(msg);

  AiSessionProvider({required AiAgentRepository aiAgentRepository})
    : _aiAgentRepository = aiAgentRepository;

  Future<void> initSession() async {
    if (_sessionId != null) return; // already have a session
    _setLoading(true);
    sessionError = false;
    _composerStatusMessage = null;
    try {
      final id = await _aiAgentRepository.createSession();
      _sessionId = id;
      messages.clear();
      _consumedMapSuggestions.clear();
      _expiredMapSuggestions.clear();
      messages.add(ChatMessage.ai(_welcomeText));
    } catch (_) {
      sessionError = true;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _sessionId == null || isLoading) return;
    _composerStatusMessage = null;

    for (final message in messages) {
      if (_hasMapShortcut(message) &&
          !_consumedMapSuggestions.contains(message)) {
        _expiredMapSuggestions.add(message);
      }
    }

    messages.add(ChatMessage.user(trimmed));
    _setLoading(true);

    try {
      final response = await _aiAgentRepository.chat(
        aiSessionId: _sessionId!,
        message: trimmed,
      );

      final preview = response.bookingPreview;

      messages.add(ChatMessage.ai(response.reply, data: response));
      if (response.readyForConfirmation && preview != null) {
        awaitingConfirmation = true;
        pendingConfirmation = preview;
      }
    } catch (_) {
      messages.add(
        ChatMessage.ai('Sorry, something went wrong. Please try again.'),
      );
    } finally {
      _setLoading(false);
    }
  }

  Future<void> confirmBooking(List<String> selectedRooms) async {
    if (_sessionId == null) return;
    awaitingConfirmation = false;
    pendingConfirmation = null;
    _setLoading(true);

    try {
      final result = await _aiAgentRepository.confirmBooking(
        aiSessionId: _sessionId!,
        selectedRooms: selectedRooms,
      );
      messages.add(ChatMessage.result(result.summary, data: result));
      if (result.success) {
        final completedSessionId = _sessionId!;
        try {
          await _aiAgentRepository.resetSession(completedSessionId);
        } catch (_) {}
        _sessionId = null;
        try {
          _sessionId = await _aiAgentRepository.createSession();
          _composerStatusMessage = null;
          messages.add(ChatMessage.divider('New Booking'));
          messages.add(
            ChatMessage.ai(
              'Your last booking is complete. Start a new request whenever you are ready.',
            ),
          );
        } catch (_) {
          _composerStatusMessage =
              'Reconnect the assistant with the refresh button to start another request.';
          messages.add(
            ChatMessage.ai(
              'Your booking is complete, but I could not start a new conversation. Tap refresh to reconnect.',
            ),
          );
        }
      }
    } catch (_) {
      messages.add(
        ChatMessage.ai('Failed to confirm booking. Please try again.'),
      );
    } finally {
      _setLoading(false);
    }
  }

  Future<void> resetSession() async {
    if (_sessionId != null) {
      try {
        await _aiAgentRepository.resetSession(_sessionId!);
      } catch (_) {}
    }
    _sessionId = null;
    messages.clear();
    _consumedMapSuggestions.clear();
    _expiredMapSuggestions.clear();
    awaitingConfirmation = false;
    pendingConfirmation = null;
    sessionError = false;
    _composerStatusMessage = null;
    notifyListeners();
    await initSession();
  }

  void cancelConfirmation() {
    awaitingConfirmation = false;
    pendingConfirmation = null;
    messages.add(ChatMessage.ai('Booking cancelled. How else can I help?'));
    notifyListeners();
  }

  /// Marks [message]'s map suggestion as consumed (e.g. user picked a room
  /// from the map sheet). Consumed suggestions render in a "completed" style.
  void markSuggestionConsumed(ChatMessage message) {
    if (_consumedMapSuggestions.add(message)) {
      notifyListeners();
    }
  }

  bool _hasMapShortcut(ChatMessage message) {
    if (message.isUser || message.data == null) return false;
    if (message.data!.readyForConfirmation) return false;

    return message.data!.suggestedOptions?.rooms.isNotEmpty ?? false;
  }

  void _setLoading(bool value) {
    isLoading = value;
    notifyListeners();
  }
}
