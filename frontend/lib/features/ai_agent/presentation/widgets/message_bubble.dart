import 'package:flutter/material.dart';
import '../../../../core/models/ai_models.dart';
import '../../../../providers/ai_session_provider.dart';
import '../../../../theme/app_theme.dart';
import 'suggestion_chips.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage msg;
  final bool isConsumed;
  final bool isExpired;
  final void Function(String) onSendMessage;
  final void Function(ChatMessage, AiChatResponse) onOpenMap;

  const MessageBubble({
    super.key,
    required this.msg,
    this.isConsumed = false,
    this.isExpired = false,
    required this.onSendMessage,
    required this.onOpenMap,
  });

  @override
  Widget build(BuildContext context) {
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

    final data = msg.data;
    final readyForConfirmation = data?.readyForConfirmation ?? false;
    final showSuggestionChips =
        !msg.isUser && data is AiChatResponse && !readyForConfirmation;
    final result = data is AiBookingResult ? data : null;
    final bool resultSuccess = msg.isResult && (result?.success ?? true);
    final bool resultFailure = msg.isResult && !resultSuccess;
    final failedReservations = result?.failedReservations ?? const [];

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
                          final session = f.session;
                          final room = f.room;
                          final reason = f.reason;
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
                  SuggestionChips(
                    message: msg,
                    data: data,
                    disableMapShortcut: isConsumed || isExpired,
                    selectedOnMap: isConsumed,
                    onSendMessage: onSendMessage,
                    onOpenMap: onOpenMap,
                  ),
              ],
            ),
          ),
          if (msg.isUser) const SizedBox(width: 40),
        ],
      ),
    );
  }
}
