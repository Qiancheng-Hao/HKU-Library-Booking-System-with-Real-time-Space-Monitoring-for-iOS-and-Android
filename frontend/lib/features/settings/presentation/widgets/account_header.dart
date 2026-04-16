import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';

class AccountHeader extends StatelessWidget {
  final String? userName;
  final String? userEmail;

  const AccountHeader({super.key, this.userName, this.userEmail});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final displayName = (userName?.trim().isNotEmpty ?? false)
        ? userName!.trim()
        : 'User';
    final email = userEmail?.trim();

    return Container(
      color: cs.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.xl,
        horizontal: AppSpacing.lg,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: cs.primaryContainer,
            child: Text(
              displayName.substring(0, 1).toUpperCase(),
              style: tt.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: cs.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (email != null && email.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Icon(
                        Icons.email_outlined,
                        size: 14,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
