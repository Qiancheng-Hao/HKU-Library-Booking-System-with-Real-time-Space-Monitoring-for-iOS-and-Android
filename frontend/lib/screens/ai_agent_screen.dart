import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ai_session_provider.dart';
import '../theme/app_theme.dart';

class AiAgentScreen extends StatefulWidget {
  const AiAgentScreen({super.key});

  @override
  State<AiAgentScreen> createState() => _AiAgentScreenState();
}

class _AiAgentScreenState extends State<AiAgentScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

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
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
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

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    _inputController.clear();
    await context.read<AiSessionProvider>().sendMessage(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AiSessionProvider>(
      builder: (context, provider, _) {
        _scrollToBottom();
        final cs = Theme.of(context).colorScheme;
        final tt = Theme.of(context).textTheme;

        return Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                border: Border(bottom: BorderSide(color: cs.outlineVariant)),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: cs.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'AI Booking Assistant',
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.primary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh, color: cs.primary),
                    tooltip: 'New conversation',
                    onPressed: provider.isLoading
                        ? null
                        : () => provider.resetSession(),
                  ),
                ],
              ),
            ),

            if (provider.sessionError)
              Expanded(child: _buildErrorState(provider))
            else ...[
              Expanded(child: _buildMessageList(provider)),
              if (provider.awaitingConfirmation &&
                  provider.pendingConfirmation != null)
                _buildConfirmationCard(provider, provider.pendingConfirmation!),
              _buildInputBar(provider),
            ],
          ],
        );
      },
    );
  }

  Widget _buildErrorState(AiSessionProvider provider) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 60, color: cs.error),
          const SizedBox(height: AppSpacing.lg),
          const Text('Failed to connect to AI service'),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(
            onPressed: () => provider.initSession(),
            child: const Text('Retry'),
          ),
        ],
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
          return _buildTypingIndicator();
        }
        return _buildMessageBubble(provider.messages[index]);
      },
    );
  }

  Widget _buildTypingIndicator() {
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            3,
            (i) => Padding(
              padding: EdgeInsets.only(left: i > 0 ? 4 : 0),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final readyForConfirmation =
        (msg.data?['readyForConfirmation'] as bool?) ?? false;
    final showSuggestionChips =
        !msg.isUser && msg.data != null && !readyForConfirmation;

    final Color bubbleColor;
    final Color textColor;
    if (msg.isUser) {
      bubbleColor = cs.primary;
      textColor = cs.onPrimary;
    } else if (msg.isResult) {
      bubbleColor = AppColors.statusAvailable.withValues(alpha: 0.12);
      textColor = cs.onSurface;
    } else {
      bubbleColor = cs.surfaceContainerHigh;
      textColor = cs.onSurface;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        mainAxisAlignment: msg.isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!msg.isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: msg.isResult
                  ? AppColors.statusAvailable
                  : cs.primaryContainer,
              child: Icon(
                msg.isResult ? Icons.check : Icons.auto_awesome_rounded,
                size: 16,
                color: msg.isResult ? Colors.white : cs.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: msg.isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: msg.isUser
                          ? const Radius.circular(18)
                          : const Radius.circular(4),
                      bottomRight: msg.isUser
                          ? const Radius.circular(4)
                          : const Radius.circular(18),
                    ),
                    border: msg.isResult
                        ? Border.all(
                            color: AppColors.statusAvailable.withValues(
                              alpha: 0.4,
                            ),
                          )
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (msg.isResult) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.statusAvailable.withValues(
                              alpha: 0.18,
                            ),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.check_circle,
                                size: 12,
                                color: AppColors.statusAvailable,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'SUCCESS',
                                style: tt.labelSmall?.copyWith(
                                  color: AppColors.statusAvailable,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                      ],
                      Text(
                        msg.text,
                        style: tt.bodyMedium?.copyWith(color: textColor),
                      ),
                    ],
                  ),
                ),
                if (showSuggestionChips) _buildSuggestionChips(msg.data!),
              ],
            ),
          ),
          if (msg.isUser) const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildSuggestionChips(Map<String, dynamic> data) {
    final cs = Theme.of(context).colorScheme;
    final opts = data['suggestedOptions'] as Map<String, dynamic>?;
    if (opts == null) return const SizedBox.shrink();
    final locations =
        (opts['locations'] as List<dynamic>?)?.cast<String>().toList() ?? [];
    final roomTypes =
        (opts['room_types'] as List<dynamic>?)?.cast<String>().toList() ?? [];
    final rooms =
        (opts['rooms'] as List<dynamic>?)?.cast<String>().toList() ?? [];

    locations.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    roomTypes.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    rooms.sort(_naturalOptionCompare);

    final all = [...locations, ...roomTypes, ...rooms];
    if (all.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: all
            .map(
              (option) => GestureDetector(
                onTap: () => _sendMessage(option),
                child: Chip(
                  label: Text(
                    option,
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSecondaryContainer,
                    ),
                  ),
                  backgroundColor: cs.secondaryContainer,
                  side: BorderSide.none,
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  int _naturalOptionCompare(String a, String b) {
    final tokenA = a.trim();
    final tokenB = b.trim();
    final numA = int.tryParse(tokenA);
    final numB = int.tryParse(tokenB);
    if (numA != null && numB != null) return numA.compareTo(numB);

    final reg = RegExp(r'^([A-Za-z]+)(\d+)$');
    final matchA = reg.firstMatch(tokenA);
    final matchB = reg.firstMatch(tokenB);
    if (matchA != null && matchB != null) {
      final prefixCompare = matchA
          .group(1)!
          .toLowerCase()
          .compareTo(matchB.group(1)!.toLowerCase());
      if (prefixCompare != 0) return prefixCompare;
      return int.parse(matchA.group(2)!).compareTo(int.parse(matchB.group(2)!));
    }
    return tokenA.toLowerCase().compareTo(tokenB.toLowerCase());
  }

  Widget _buildConfirmationCard(
    AiSessionProvider provider,
    Map<String, dynamic> preview,
  ) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final library = preview['library'] as String? ?? 'N/A';
    final date = preview['date'] as String? ?? 'N/A';
    final timeRanges =
        (preview['time_ranges'] as List<dynamic>?)?.cast<String>() ?? [];
    final candidateRooms =
        (preview['candidate_rooms'] as List<dynamic>?)?.cast<String>() ?? [];
    final libraryFacilityLabel = candidateRooms.isNotEmpty
        ? '$library - ${candidateRooms.join(', ')}'
        : library;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_outline, color: cs.primary, size: 18),
              const SizedBox(width: 6),
              Text(
                'Booking Preview',
                style: tt.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: cs.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _previewRow(Icons.local_library, libraryFacilityLabel),
          _previewRow(Icons.calendar_today, date),
          if (timeRanges.isNotEmpty)
            _previewRow(Icons.access_time, timeRanges.join(', ')),
          if (candidateRooms.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Booking facility:',
              style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: candidateRooms
                  .map(
                    (room) => Chip(
                      label: Text(
                        room,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSecondaryContainer,
                        ),
                      ),
                      backgroundColor: cs.secondaryContainer,
                      side: BorderSide.none,
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => provider.cancelConfirmation(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => provider.confirmBooking(candidateRooms),
                  child: const Text('Confirm'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _previewRow(IconData icon, String value) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: cs.primary),
          const SizedBox(width: 6),
          Expanded(child: Text(value, style: tt.bodySmall)),
        ],
      ),
    );
  }

  Widget _buildInputBar(AiSessionProvider provider) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              onSubmitted: _sendMessage,
              enabled: !provider.isLoading && provider.hasSession,
              textInputAction: TextInputAction.send,
              decoration: InputDecoration(
                hintText: 'Type your request...',
                hintStyle: TextStyle(color: cs.onSurfaceVariant),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          CircleAvatar(
            backgroundColor: cs.primary,
            child: IconButton(
              icon: Icon(Icons.send, color: cs.onPrimary, size: 20),
              onPressed: provider.isLoading
                  ? null
                  : () => _sendMessage(_inputController.text),
            ),
          ),
        ],
      ),
    );
  }
}
