import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';

class ChatHeader extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onReset;

  const ChatHeader({super.key, required this.isLoading, required this.onReset});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
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
            onPressed: isLoading ? null : onReset,
          ),
        ],
      ),
    );
  }
}
