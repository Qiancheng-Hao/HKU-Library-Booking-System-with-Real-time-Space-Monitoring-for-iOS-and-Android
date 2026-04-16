import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';

class GreetingHeader extends StatelessWidget {
  final String greeting;
  final String userName;

  const GreetingHeader({
    super.key,
    required this.greeting,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greeting,
          style: tt.headlineSmall?.copyWith(
            fontWeight: FontWeight.w300,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          userName,
          style: tt.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: cs.primary,
          ),
        ),
      ],
    );
  }
}
