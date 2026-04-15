import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ai_session_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/ai_map_selector.dart';

class AiAgentScreen extends StatefulWidget {
  const AiAgentScreen({super.key});

  @override
  State<AiAgentScreen> createState() => _AiAgentScreenState();
}

class _AiAgentScreenState extends State<AiAgentScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();
  final Set<ChatMessage> _consumedMapSuggestions = {};
  final Set<ChatMessage> _expiredMapSuggestions = {};

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
    _inputFocusNode.dispose();
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
    if (mounted) {
      setState(() {
        for (final message in provider.messages) {
          if (_hasMapShortcut(message) &&
              !_consumedMapSuggestions.contains(message)) {
            _expiredMapSuggestions.add(message);
          }
        }
      });
    }
    _inputController.clear();
    _inputFocusNode.requestFocus();
    await provider.sendMessage(text);
    _scrollToBottom();
  }

  bool _hasMapShortcut(ChatMessage message) {
    if (message.isUser || message.data == null) return false;
    final readyForConfirmation =
        (message.data?['readyForConfirmation'] as bool?) ?? false;
    if (readyForConfirmation) return false;

    final opts = message.data?['suggestedOptions'] as Map<String, dynamic>?;
    final rooms = (opts?['rooms'] as List<dynamic>?) ?? const [];
    return rooms.isNotEmpty;
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
                        : () {
                            setState(() {
                              _consumedMapSuggestions.clear();
                              _expiredMapSuggestions.clear();
                            });
                            provider.resetSession();
                          },
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
        child: _BouncingDots(color: cs.onSurfaceVariant),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (msg.isDivider) {
      return Container(
        margin: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Divider(
                color: cs.outlineVariant.withValues(alpha: 0.8),
                height: 1,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text(
                msg.text,
                style: tt.labelMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            Expanded(
              child: Divider(
                color: cs.outlineVariant.withValues(alpha: 0.8),
                height: 1,
              ),
            ),
          ],
        ),
      );
    }

    final readyForConfirmation =
        (msg.data?['readyForConfirmation'] as bool?) ?? false;
    final showSuggestionChips =
        !msg.isUser && msg.data != null && !readyForConfirmation;

    final bool resultSuccess =
        msg.isResult && ((msg.data?['success'] as bool?) ?? true);
    final bool resultFailure = msg.isResult && !resultSuccess;

    final Color bubbleColor;
    final Color textColor;
    if (msg.isUser) {
      bubbleColor = cs.primary;
      textColor = cs.onPrimary;
    } else if (resultFailure) {
      bubbleColor = cs.errorContainer.withValues(alpha: 0.35);
      textColor = cs.onSurface;
    } else if (msg.isResult) {
      bubbleColor = AppColors.statusAvailable.withValues(alpha: 0.12);
      textColor = cs.onSurface;
    } else {
      bubbleColor = cs.surfaceContainerHigh;
      textColor = cs.onSurface;
    }

    final failedReservations = msg.isResult
        ? (msg.data?['failedReservations'] as List<dynamic>? ?? [])
        : <dynamic>[];

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
              backgroundColor: resultFailure
                  ? cs.error
                  : msg.isResult
                  ? AppColors.statusAvailable
                  : cs.primaryContainer,
              child: Icon(
                resultFailure
                    ? Icons.close
                    : msg.isResult
                    ? Icons.check
                    : Icons.auto_awesome_rounded,
                size: 16,
                color: (resultFailure || msg.isResult)
                    ? Colors.white
                    : cs.onPrimaryContainer,
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
                            color: resultFailure
                                ? cs.error.withValues(alpha: 0.4)
                                : AppColors.statusAvailable.withValues(
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
                            color: resultFailure
                                ? cs.error.withValues(alpha: 0.15)
                                : AppColors.statusAvailable.withValues(
                                    alpha: 0.18,
                                  ),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                resultFailure
                                    ? Icons.cancel
                                    : Icons.check_circle,
                                size: 12,
                                color: resultFailure
                                    ? cs.error
                                    : AppColors.statusAvailable,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                resultFailure ? 'FAILED' : 'SUCCESS',
                                style: tt.labelSmall?.copyWith(
                                  color: resultFailure
                                      ? cs.error
                                      : AppColors.statusAvailable,
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
                      if (failedReservations.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        ...failedReservations.map((f) {
                          final item = f as Map<String, dynamic>;
                          final session = item['session'] as String? ?? '';
                          final room = item['room'] as String? ?? '';
                          final reason = item['reason'] as String? ?? '';
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 13,
                                  color: cs.error,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '${session.isNotEmpty ? '$session ' : ''}${room.isNotEmpty ? '($room): ' : ''}$reason',
                                    style: tt.bodySmall?.copyWith(
                                      color: cs.error,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
                if (showSuggestionChips)
                  _buildSuggestionChips(
                    msg,
                    msg.data!,
                    disableMapShortcut:
                        _consumedMapSuggestions.contains(msg) ||
                        _expiredMapSuggestions.contains(msg),
                    selectedOnMap: _consumedMapSuggestions.contains(msg),
                  ),
              ],
            ),
          ),
          if (msg.isUser) const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildSuggestionChips(
    ChatMessage message,
    Map<String, dynamic> data, {
    bool disableMapShortcut = false,
    bool selectedOnMap = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final opts = data['suggestedOptions'] as Map<String, dynamic>?;
    if (opts == null) return const SizedBox.shrink();
    final collectedInfo = data['collectedInfo'] as Map<String, dynamic>?;

    final locations =
        (opts['locations'] as List<dynamic>?)?.cast<String>().toList() ?? [];
    final roomTypes =
        (opts['room_types'] as List<dynamic>?)?.cast<String>().toList() ?? [];
    final rooms =
        (opts['rooms'] as List<dynamic>?)?.cast<String>().toList() ?? [];

    locations.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    roomTypes.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    rooms.sort(_naturalOptionCompare);

    String? locationHint = locations.isNotEmpty ? locations.first : null;
    if (locationHint == null) {
      final preview = data['bookingPreview'] as Map<String, dynamic>?;
      locationHint = preview?['library'] as String?;
    }
    final roomTypeCode = collectedInfo?['room_type_code'] as String?;
    final roomTypeLabel =
        collectedInfo?['room_type'] as String? ??
        (roomTypes.length == 1 ? roomTypes.first : null);

    final nonRoomOptions = [...locations, ...roomTypes];
    if (nonRoomOptions.isEmpty && rooms.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (nonRoomOptions.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: nonRoomOptions
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

          if (rooms.isNotEmpty) ...[
            if (nonRoomOptions.isNotEmpty) const SizedBox(height: 8),
            GestureDetector(
              onTap: disableMapShortcut
                  ? null
                  : () => _openMapSelector(
                      sourceMessage: message,
                      locationHint: locationHint,
                      rooms: rooms,
                      roomTypeCode: roomTypeCode,
                      roomTypeLabel: roomTypeLabel,
                    ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: disableMapShortcut
                      ? cs.surfaceContainerHigh
                      : cs.primaryContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: disableMapShortcut
                        ? cs.outlineVariant
                        : cs.primary.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.map_outlined,
                      size: 16,
                      color: disableMapShortcut
                          ? cs.onSurfaceVariant
                          : cs.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      disableMapShortcut
                          ? (selectedOnMap
                                ? 'Selected on Map'
                                : 'Map Options Expired')
                          : 'View on Map  (${rooms.length} available)',
                      style: tt.bodySmall?.copyWith(
                        color: disableMapShortcut
                            ? cs.onSurfaceVariant
                            : cs.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      disableMapShortcut
                          ? (selectedOnMap ? Icons.check_circle : Icons.block)
                          : Icons.chevron_right,
                      size: disableMapShortcut ? 14 : 16,
                      color: disableMapShortcut
                          ? cs.onSurfaceVariant
                          : cs.primary.withValues(alpha: 0.7),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
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
            setState(() {
              _consumedMapSuggestions.add(sourceMessage);
            });
          }
          final message = selected.join(', ');
          _sendMessage(message);
        },
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
              focusNode: _inputFocusNode,
              onSubmitted: _sendMessage,
              enabled: provider.hasSession,
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

class _BouncingDots extends StatefulWidget {
  final Color color;
  const _BouncingDots({required this.color});

  @override
  State<_BouncingDots> createState() => _BouncingDotsState();
}

class _BouncingDotsState extends State<_BouncingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => CustomPaint(
          size: const Size(36, 16),
          painter: _DotsPainter(
            progress: _controller.value,
            color: widget.color,
          ),
        ),
      ),
    );
  }
}

class _DotsPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _DotsPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    const dotRadius = 4.0;
    const spacing = 5.0;
    const amplitude = 5.0;
    const totalWidth = 3 * dotRadius * 2 + 2 * spacing;
    final startX = (size.width - totalWidth) / 2 + dotRadius;
    final centerY = size.height / 2;

    for (int i = 0; i < 3; i++) {
      final phase = (progress - i / 3.0) % 1.0;
      final dy = -math.sin(phase * 2 * math.pi).abs() * amplitude;
      final cx = startX + i * (dotRadius * 2 + spacing);
      canvas.drawCircle(Offset(cx, centerY + dy), dotRadius, paint);
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) =>
      old.progress != progress || old.color != color;
}
