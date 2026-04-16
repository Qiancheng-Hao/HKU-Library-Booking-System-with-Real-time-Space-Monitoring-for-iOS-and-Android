import 'package:flutter/material.dart';
import '../../../../providers/notification_provider.dart';
import '../../../../services/notification_service.dart';
import '../../../../theme/app_theme.dart';
import 'settings_section.dart';

class NotificationSection extends StatelessWidget {
  final bool permissionGranted;
  final bool enabled;
  final int reminderMinutes;
  final bool isBusy;
  final Future<void> Function(bool) onToggleEnabled;
  final Future<void> Function(int) onReminderMinutesChanged;

  const NotificationSection({
    super.key,
    required this.permissionGranted,
    required this.enabled,
    required this.reminderMinutes,
    required this.isBusy,
    required this.onToggleEnabled,
    required this.onReminderMinutesChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return SettingsSection(
      title: 'Notifications',
      children: [
        if (!permissionGranted)
          ListTile(
            leading: Icon(
              Icons.notifications_active_outlined,
              color: cs.primary,
            ),
            title: const Text('Notification access'),
            subtitle: Text(
              'Turn this on in Settings to receive booking reminders on time.',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            trailing: FilledButton.tonal(
              onPressed: isBusy
                  ? null
                  : NotificationService.openNotificationSettings,
              style: FilledButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: tt.labelSmall,
              ),
              child: const Text('Open Settings'),
            ),
          ),
        if (permissionGranted) ...[
          SwitchListTile(
            secondary: Icon(Icons.notifications_outlined, color: cs.primary),
            title: const Text('Booking reminders'),
            subtitle: Text(
              isBusy
                  ? 'Updating your reminder settings...'
                  : 'Get a reminder before your reservation starts.',
            ),
            value: enabled,
            onChanged: isBusy ? null : onToggleEnabled,
          ),
          if (enabled)
            Padding(
              padding: SettingsSection.contentPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isBusy) ...[
                    const LinearProgressIndicator(minHeight: 2),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  Row(
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        color: cs.onSurfaceVariant,
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text('Remind me before', style: tt.bodyMedium),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Choose how early we should notify you.',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<int>(
                      expandedInsets: EdgeInsets.zero,
                      segments: NotificationProvider.reminderOptions
                          .map(
                            (m) => ButtonSegment<int>(
                              value: m,
                              label: Text('${m}m'),
                            ),
                          )
                          .toList(),
                      selected: {reminderMinutes},
                      onSelectionChanged: isBusy
                          ? null
                          : (s) async => onReminderMinutesChanged(s.first),
                      style: ButtonStyle(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        textStyle: WidgetStatePropertyAll(tt.labelSmall),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
