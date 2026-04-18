import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/models/ai_models.dart';
import '../../../../providers/ai_session_provider.dart';
import '../../../../theme/app_theme.dart';
import '../widgets/ai_map_selector.dart';
import '../widgets/chat_error_state.dart';
import '../widgets/chat_header.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/confirmation_card.dart';
import '../widgets/message_bubble.dart';
import '../widgets/typing_indicator.dart';

class AiAgentScreen extends StatefulWidget {
  const AiAgentScreen({super.key});

  @override
  State<AiAgentScreen> createState() => _AiAgentScreenState();
}

class _AiAgentScreenState extends State<AiAgentScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();
  AiSessionProvider? _provider;
  int _lastVisibleItemCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AiSessionProvider>();
      if (!provider.hasSession && !provider.isLoading) {
        provider.initSession();
      }
    });
  }

  @override
  void dispose() {
    _provider?.removeListener(_handleProviderChanged);
    _inputController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<AiSessionProvider>();
    if (identical(provider, _provider)) return;
    _provider?.removeListener(_handleProviderChanged);
    _provider = provider;
    _lastVisibleItemCount = _visibleItemCount(provider);
    provider.addListener(_handleProviderChanged);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  int _visibleItemCount(AiSessionProvider provider) {
    return provider.messages.length + (provider.isLoading ? 1 : 0);
  }

  void _handleProviderChanged() {
    if (!mounted || _provider == null) return;
    final visibleItemCount = _visibleItemCount(_provider!);
    if (visibleItemCount == _lastVisibleItemCount) return;
    _lastVisibleItemCount = visibleItemCount;
    _scrollToBottom();
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    final provider = context.read<AiSessionProvider>();
    if (provider.isLoading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait for the reply...'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    _inputController.clear();
    _inputFocusNode.requestFocus();
    await provider.sendMessage(text);
    _scrollToBottom();
  }

  void _handleOpenMap(ChatMessage sourceMessage, AiChatResponse data) {
    final opts = data.suggestedOptions;
    final rooms = opts?.rooms ?? [];
    final collectedInfo = data.collectedInfo;

    final locationHint =
        opts?.locations.firstOrNull ?? data.bookingPreview?.library;

    final roomTypeCode = collectedInfo?.roomTypeCode;
    final roomTypeLabel = collectedInfo?.roomType;

    _openMapSelector(
      sourceMessage: sourceMessage,
      locationHint: locationHint,
      rooms: rooms,
      roomTypeCode: roomTypeCode,
      roomTypeLabel: roomTypeLabel,
    );
  }

  void _openMapSelector({
    required ChatMessage sourceMessage,
    required String? locationHint,
    required List<String> rooms,
    String? roomTypeCode,
    String? roomTypeLabel,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AiMapSelectorSheet(
        locationHint: locationHint,
        availableRoomNames: rooms,
        roomTypeCode: roomTypeCode,
        roomTypeLabel: roomTypeLabel,
        onConfirm: (selected) {
          if (mounted) {
            context.read<AiSessionProvider>().markSuggestionConsumed(
              sourceMessage,
            );
          }
          final message = selected.join(', ');
          _sendMessage(message);
        },
      ),
    );
  }

  Widget _buildMessageList(AiSessionProvider provider) {
    if (provider.messages.isEmpty && provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final itemCount = provider.messages.length + (provider.isLoading ? 1 : 0);
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == provider.messages.length) {
          return const TypingIndicator();
        }
        final msg = provider.messages[index];
        return MessageBubble(
          key: ValueKey(msg),
          msg: msg,
          isConsumed: provider.isSuggestionConsumed(msg),
          isExpired: provider.isSuggestionExpired(msg),
          onSendMessage: _sendMessage,
          onOpenMap: _handleOpenMap,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AiSessionProvider>(
      builder: (context, provider, _) {
        return Column(
          children: [
            ChatHeader(
              isLoading: provider.isLoading,
              onReset: provider.resetSession,
            ),
            if (provider.sessionError)
              Expanded(child: ChatErrorState(onRetry: provider.initSession))
            else ...[
              Expanded(child: _buildMessageList(provider)),
              if (provider.awaitingConfirmation &&
                  provider.pendingConfirmation != null)
                ConfirmationCard(
                  preview: provider.pendingConfirmation!,
                  onChangeRoom: provider.changeRoomSelection,
                  onChangeTime: provider.changeTimeSelection,
                  onCancel: provider.cancelConfirmation,
                  onConfirm: provider.confirmBooking,
                ),
              ChatInputBar(
                controller: _inputController,
                focusNode: _inputFocusNode,
                hasSession: provider.hasSession,
                isLoading: provider.isLoading,
                statusMessage: provider.composerStatusMessage,
                onSend: _sendMessage,
              ),
            ],
          ],
        );
      },
    );
  }
}
