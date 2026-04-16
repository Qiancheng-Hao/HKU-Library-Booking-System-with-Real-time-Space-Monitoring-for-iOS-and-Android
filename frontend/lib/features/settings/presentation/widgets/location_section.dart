import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../theme/app_theme.dart';
import 'settings_section.dart';

class LocationSection extends StatelessWidget {
  final LocationPermission permission;
  final bool isBusy;
  final Future<void> Function() onPermissionAction;

  const LocationSection({
    super.key,
    required this.permission,
    required this.isBusy,
    required this.onPermissionAction,
  });

  String _permissionLabel(LocationPermission p) {
    return switch (p) {
      LocationPermission.always => 'Location access is always on',
      LocationPermission.whileInUse =>
        'Location access is on while using the app',
      LocationPermission.denied => 'Location access is off',
      LocationPermission.deniedForever =>
        'Location access is blocked in system settings',
      _ => 'Location access status is unavailable',
    };
  }

  Color _permissionColor(LocationPermission p, ColorScheme cs) {
    return switch (p) {
      LocationPermission.always => AppColors.statusAvailable,
      LocationPermission.whileInUse => AppColors.statusAvailable,
      LocationPermission.denied => AppColors.statusModerate,
      LocationPermission.deniedForever => AppColors.statusBusy,
      _ => cs.onSurfaceVariant,
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return SettingsSection(
      title: 'Location',
      children: [
        ListTile(
          leading: Icon(Icons.location_on_outlined, color: cs.primary),
          title: const Text('Location access'),
          subtitle: Text(
            _permissionLabel(permission),
            style: TextStyle(color: _permissionColor(permission, cs)),
          ),
          trailing:
              (permission == LocationPermission.denied ||
                  permission == LocationPermission.deniedForever)
              ? FilledButton.tonal(
                  onPressed: isBusy ? null : onPermissionAction,
                  style: FilledButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: tt.labelSmall,
                  ),
                  child: Text(
                    permission == LocationPermission.deniedForever
                        ? 'Open Settings'
                        : 'Allow',
                  ),
                )
              : Icon(
                  Icons.check_circle_outline,
                  color: AppColors.statusAvailable,
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.xs,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isBusy) ...[
                const LinearProgressIndicator(minHeight: 2),
                const SizedBox(height: AppSpacing.sm),
              ],
              Text(
                permission == LocationPermission.always ||
                        permission == LocationPermission.whileInUse
                    ? 'Used to improve nearby suggestions and location-aware features.'
                    : 'Allow location if you want better nearby recommendations in the app.',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
