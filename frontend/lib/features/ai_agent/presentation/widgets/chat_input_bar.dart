import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';

class ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasSession;
  final bool isLoading;
  final String? statusMessage;
  final void Function(String) onSend;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hasSession,
    required this.isLoading,
    this.statusMessage,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canSend = hasSession && !isLoading;
    final hintText = hasSession
        ? 'Type your request...'
        : 'Reconnect the assistant to keep going';

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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onSubmitted: onSend,
                  enabled: hasSession,
                  textInputAction: TextInputAction.send,
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              CircleAvatar(
                backgroundColor: canSend
                    ? cs.primary
                    : cs.surfaceContainerHighest,
                child: IconButton(
                  icon: Icon(
                    Icons.send,
                    color: canSend ? cs.onPrimary : cs.onSurfaceVariant,
                    size: 20,
                  ),
                  onPressed: canSend ? () => onSend(controller.text) : null,
                ),
              ),
            ],
          ),
          if (statusMessage != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                statusMessage!,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
