import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';

class ChatErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const ChatErrorState({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 60, color: cs.error),
          const SizedBox(height: AppSpacing.lg),
          const Text('Failed to connect to AI service'),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
