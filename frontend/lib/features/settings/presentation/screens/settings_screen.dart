import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/notification_provider.dart';
import '../../../../providers/theme_provider.dart';
import '../../../../services/notification_service.dart';
import '../../../../theme/app_theme.dart';
import '../widgets/account_header.dart';
import '../widgets/appearance_section.dart';
import '../widgets/location_section.dart';
import '../widgets/notification_section.dart';
import '../widgets/settings_section.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  LocationPermission _locationPermission = LocationPermission.denied;
  bool _notificationPermissionGranted = false;
  bool _isUpdatingNotifications = false;
  bool _isUpdatingLocationPermission = false;

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
    if (_isUpdatingNotifications) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isUpdatingNotifications = true);
    try {
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
    } finally {
      if (mounted) {
        setState(() => _isUpdatingNotifications = false);
      }
    }
  }

  Future<void> _checkLocationPermission() async {
    final permission = await Geolocator.checkPermission();
    if (mounted) setState(() => _locationPermission = permission);
  }

  Future<void> _handleLocationPermissionAction() async {
    if (_isUpdatingLocationPermission) return;
    setState(() => _isUpdatingLocationPermission = true);
    try {
      if (_locationPermission == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
        await _checkLocationPermission();
        return;
      }

      final permission = await Geolocator.requestPermission();
      if (mounted) {
        setState(() => _locationPermission = permission);
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingLocationPermission = false);
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: ListView(
        children: [
          Consumer<AuthProvider>(
            builder: (context, auth, child) => AccountHeader(
              userName: auth.userName,
              userEmail: auth.userEmail,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Selector<ThemeProvider, ThemeMode>(
            selector: (context, themeProvider) => themeProvider.themeMode,
            builder: (context, themeMode, child) => AppearanceSection(
              themeMode: themeMode,
              onChanged: context.read<ThemeProvider>().setThemeMode,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Consumer<NotificationProvider>(
            builder: (context, notifProvider, child) => NotificationSection(
              permissionGranted: _notificationPermissionGranted,
              enabled: notifProvider.enabled,
              reminderMinutes: notifProvider.reminderMinutes,
              isBusy: _isUpdatingNotifications,
              onToggleEnabled: (value) async {
                if (value) {
                  await _requestNotificationPermission(notifProvider);
                  return;
                }
                if (_isUpdatingNotifications) return;
                setState(() => _isUpdatingNotifications = true);
                try {
                  await notifProvider.setEnabled(false);
                  await _checkNotificationPermission();
                } finally {
                  if (mounted) {
                    setState(() => _isUpdatingNotifications = false);
                  }
                }
              },
              onReminderMinutesChanged: (minutes) async {
                if (_isUpdatingNotifications) return;
                setState(() => _isUpdatingNotifications = true);
                try {
                  await notifProvider.setReminderMinutes(minutes);
                } finally {
                  if (mounted) {
                    setState(() => _isUpdatingNotifications = false);
                  }
                }
              },
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          LocationSection(
            permission: _locationPermission,
            isBusy: _isUpdatingLocationPermission,
            onPermissionAction: _handleLocationPermissionAction,
          ),
          const SizedBox(height: AppSpacing.lg),
          SettingsSection(
            title: 'General',
            children: [
              ListTile(
                leading: Icon(Icons.info_outline, color: cs.primary),
                title: const Text('About'),
                trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                onTap: _showAboutDialog,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Consumer<AuthProvider>(
              builder: (context, auth, child) => OutlinedButton(
                onPressed: () => _handleLogout(auth),
                style: OutlinedButton.styleFrom(
                  foregroundColor: cs.error,
                  side: BorderSide(color: cs.error.withValues(alpha: 0.5)),
                ),
                child: const Text('Log Out'),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}
