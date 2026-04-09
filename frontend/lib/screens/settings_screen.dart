import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/theme_provider.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  LocationPermission _locationPermission = LocationPermission.denied;
  bool _notificationPermissionGranted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkLocationPermission();
    _checkNotificationPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkLocationPermission();
      _checkNotificationPermission();
    }
  }

  Future<void> _checkNotificationPermission() async {
    final granted = await NotificationService.hasSystemPermission();
    if (!granted && mounted) {
      await context.read<NotificationProvider>().setEnabled(false);
    }
    if (mounted) {
      setState(() => _notificationPermissionGranted = granted);
    }
  }

  Future<void> _requestNotificationPermission(
    NotificationProvider notifProvider,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final changed = await notifProvider.setEnabled(true);
    if (!mounted) return;

    if (changed) {
      await _checkNotificationPermission();
      return;
    }

    await _checkNotificationPermission();
    messenger.showSnackBar(
      SnackBar(
        content: const Text(
          'Notification permission is off. Open Settings to enable it.',
        ),
        action: SnackBarAction(
          label: 'Settings',
          onPressed: NotificationService.openNotificationSettings,
        ),
      ),
    );
  }

  Future<void> _checkLocationPermission() async {
    final permission = await Geolocator.checkPermission();
    if (mounted) setState(() => _locationPermission = permission);
  }

  Future<void> _handleLogout(AuthProvider authProvider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await authProvider.logout();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Logged out')));
      }
    }
  }

  Future<void> _showAboutDialog() async {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.xl,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.local_library_rounded,
                      color: cs.onPrimaryContainer,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'HKU Library Booking',
                          style: tt.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Version 1.0.0',
                          style: tt.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'A prototype for library booking, seat discovery, and real-time space monitoring.',
                style: tt.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Final Year Project, The University of Hong Kong.',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  TextButton(
                    onPressed: () => showLicensePage(
                      context: context,
                      applicationName: 'HKU Library Booking',
                      applicationVersion: '1.0.0',
                      applicationLegalese:
                          'Final Year Project, The University of Hong Kong',
                    ),
                    child: const Text('View Licenses'),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.sm,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _permissionLabel(LocationPermission p) {
    return switch (p) {
      LocationPermission.always => 'Always allowed',
      LocationPermission.whileInUse => 'Allowed while using',
      LocationPermission.denied => 'Denied',
      LocationPermission.deniedForever => 'Permanently denied',
      _ => 'Unknown',
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

  String _notificationPermissionLabel() {
    return _notificationPermissionGranted ? 'Allowed' : 'Denied';
  }

  Color _notificationPermissionColor(ColorScheme cs) {
    return _notificationPermissionGranted
        ? AppColors.statusAvailable
        : AppColors.statusBusy;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Consumer3<AuthProvider, ThemeProvider, NotificationProvider>(
      builder: (context, auth, themeProvider, notifProvider, child) {
        return Scaffold(
          body: ListView(
            children: [
              // ── Account section ──────────────────────────────────────────
              Container(
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
                        (auth.userName ?? 'U').substring(0, 1).toUpperCase(),
                        style: tt.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          auth.userName ?? '',
                          style: tt.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (auth.userEmail != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Row(
                            children: [
                              Icon(
                                Icons.email_outlined,
                                size: 14,
                                color: cs.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                auth.userEmail!,
                                style: tt.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // ── Appearance ───────────────────────────────────────────────
              _sectionLabel('Appearance', cs, tt),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.xs,
                ),
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode_outlined),
                      label: Text('Light'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.contrast_outlined),
                      label: Text('System'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode_outlined),
                      label: Text('Dark'),
                    ),
                  ],
                  selected: {themeProvider.themeMode},
                  onSelectionChanged: (s) =>
                      themeProvider.setThemeMode(s.first),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // ── Notifications ────────────────────────────────────────────
              _sectionLabel('Notifications', cs, tt),
              if (!_notificationPermissionGranted)
                ListTile(
                  leading: Icon(
                    Icons.notifications_active_outlined,
                    color: cs.primary,
                  ),
                  title: const Text('Notification permission'),
                  subtitle: Text(
                    _notificationPermissionLabel(),
                    style: TextStyle(color: _notificationPermissionColor(cs)),
                  ),
                  trailing: FilledButton.tonal(
                    onPressed: NotificationService.openNotificationSettings,
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
              if (_notificationPermissionGranted) ...[
                SwitchListTile(
                  secondary: Icon(
                    Icons.notifications_outlined,
                    color: cs.primary,
                  ),
                  title: const Text('Booking reminders'),
                  subtitle: const Text('Notify me before my reservation'),
                  value: notifProvider.enabled,
                  onChanged: (value) async {
                    if (value) {
                      await _requestNotificationPermission(notifProvider);
                    } else {
                      await notifProvider.setEnabled(false);
                      await _checkNotificationPermission();
                    }
                  },
                ),
                if (notifProvider.enabled)
                  ListTile(
                    leading: Icon(
                      Icons.timer_outlined,
                      color: cs.onSurfaceVariant,
                    ),
                    title: Text('Remind me before', style: tt.bodyMedium),
                    trailing: SegmentedButton<int>(
                      segments: NotificationProvider.reminderOptions
                          .map(
                            (m) => ButtonSegment<int>(
                              value: m,
                              label: Text('${m}m'),
                            ),
                          )
                          .toList(),
                      selected: {notifProvider.reminderMinutes},
                      onSelectionChanged: (s) =>
                          notifProvider.setReminderMinutes(s.first),
                      style: ButtonStyle(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        textStyle: WidgetStatePropertyAll(tt.labelSmall),
                      ),
                    ),
                  ),
              ],

              const SizedBox(height: AppSpacing.lg),

              // ── Location ─────────────────────────────────────────────────
              _sectionLabel('Location', cs, tt),
              ListTile(
                leading: Icon(Icons.location_on_outlined, color: cs.primary),
                title: const Text('Location permission'),
                subtitle: Text(
                  _permissionLabel(_locationPermission),
                  style: TextStyle(
                    color: _permissionColor(_locationPermission, cs),
                  ),
                ),
                trailing:
                    (_locationPermission == LocationPermission.denied ||
                        _locationPermission == LocationPermission.deniedForever)
                    ? FilledButton.tonal(
                        onPressed: () async {
                          if (_locationPermission ==
                              LocationPermission.deniedForever) {
                            await Geolocator.openAppSettings();
                          } else {
                            final result = await Geolocator.requestPermission();
                            if (mounted) {
                              setState(() => _locationPermission = result);
                            }
                          }
                        },
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
                          _locationPermission ==
                                  LocationPermission.deniedForever
                              ? 'Open Settings'
                              : 'Allow',
                        ),
                      )
                    : Icon(
                        Icons.check_circle_outline,
                        color: AppColors.statusAvailable,
                      ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // ── General ──────────────────────────────────────────────────
              _sectionLabel('General', cs, tt),
              _buildSettingItem(
                icon: Icons.info_outline,
                title: 'About',
                onTap: _showAboutDialog,
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Logout ───────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: OutlinedButton(
                  onPressed: () => _handleLogout(auth),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: cs.error,
                    side: BorderSide(color: cs.error.withValues(alpha: 0.5)),
                  ),
                  child: const Text('Log Out'),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionLabel(String label, ColorScheme cs, TextTheme tt) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Text(
        label,
        style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: cs.primary),
      title: Text(title),
      trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
      onTap: onTap,
    );
  }
}
