import 'package:flutter/material.dart';
import '../services/api_service.dart';

enum _MessageType { user, ai, result, divider }

class ChatMessage {
  final String text;
  final _MessageType _type;
  final Map<String, dynamic>? data;

  ChatMessage._({required this.text, required _MessageType type, this.data})
    : _type = type;

  factory ChatMessage.user(String text) =>
      ChatMessage._(text: text, type: _MessageType.user);

  factory ChatMessage.ai(String text, {Map<String, dynamic>? data}) =>
      ChatMessage._(text: text, type: _MessageType.ai, data: data);

  factory ChatMessage.result(String text, {Map<String, dynamic>? data}) =>
      ChatMessage._(text: text, type: _MessageType.result, data: data);

  factory ChatMessage.divider(String text) =>
      ChatMessage._(text: text, type: _MessageType.divider);

  bool get isUser => _type == _MessageType.user;
  bool get isResult => _type == _MessageType.result;
  bool get isAi => _type == _MessageType.ai;
  bool get isDivider => _type == _MessageType.divider;
}

class AiSessionProvider extends ChangeNotifier {
  final List<ChatMessage> messages = [];
  static const _welcomeText =
      "Hi! I'm your AI booking assistant. Tell me what you need — "
      'for example: "Book a study room at Main Library tomorrow afternoon."';

  String? _sessionId;
  bool isLoading = false;
  bool sessionError = false;
  bool awaitingConfirmation = false;
  Map<String, dynamic>? pendingConfirmation;

  String? get sessionId => _sessionId;
  bool get hasSession => _sessionId != null;

  Future<void> initSession() async {
    if (_sessionId != null) return; // already have a session
    _setLoading(true);
    sessionError = false;
    try {
      final id = await ApiService.createAiSession();
      _sessionId = id;
      messages.clear();
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

    messages.add(ChatMessage.user(trimmed));
    _setLoading(true);

    try {
      final response = await ApiService.chatWithAi(
        aiSessionId: _sessionId!,
        message: trimmed,
      );

      final reply = response['reply'] as String? ?? '';
      final ready = response['readyForConfirmation'] as bool? ?? false;
      final preview = response['bookingPreview'] as Map<String, dynamic>?;

      messages.add(ChatMessage.ai(reply, data: response));
      if (ready && preview != null) {
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
      final result = await ApiService.confirmAiBooking(
        aiSessionId: _sessionId!,
        selectedRooms: selectedRooms,
      );
      messages.add(
        ChatMessage.result(
          result['summary'] as String? ?? 'Booking processed.',
          data: result,
        ),
      );
      final succeeded = result['success'] as bool? ?? false;
      if (succeeded) {
        try {
          await ApiService.resetAiSession(_sessionId!);
        } catch (_) {}
        messages.add(ChatMessage.divider('New Booking'));
        messages.add(
          ChatMessage.ai(
            'Your last booking is complete. Start a new request whenever you are ready.',
          ),
        );
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
        await ApiService.resetAiSession(_sessionId!);
      } catch (_) {}
    }
    _sessionId = null;
    messages.clear();
    awaitingConfirmation = false;
    pendingConfirmation = null;
    sessionError = false;
    notifyListeners();
    await initSession();
  }

  void cancelConfirmation() {
    awaitingConfirmation = false;
    pendingConfirmation = null;
    messages.add(ChatMessage.ai('Booking cancelled. How else can I help?'));
    notifyListeners();
  }

  void _setLoading(bool value) {
    isLoading = value;
    notifyListeners();
  }
}
