import 'package:frontend/features/ai_agent/presentation/widgets/chat_input_bar.dart';
import 'package:frontend/features/reservations/presentation/widgets/reservation_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:frontend/core/models/reservation.dart';
import 'package:frontend/features/settings/presentation/widgets/account_header.dart';
import 'package:frontend/features/settings/presentation/widgets/appearance_section.dart';
import 'package:frontend/features/settings/presentation/widgets/location_section.dart';
import 'package:frontend/features/settings/presentation/widgets/notification_section.dart';
import 'package:frontend/theme/app_theme.dart';

void main() {
  testWidgets('AppearanceSection keeps segmented control full width', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: AppearanceSection(
              themeMode: ThemeMode.dark,
              onChanged: _noopThemeChange,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Light'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);

    final segmentedButton = find.byWidgetPredicate(
      (widget) => widget is SegmentedButton<ThemeMode>,
    );
    final width = tester.getSize(segmentedButton).width;

    expect(width, closeTo(360 - (AppSpacing.lg * 2), 0.1));
  });

  testWidgets('AccountHeader stays stable with long user details', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 220,
            child: AccountHeader(
              userName: 'A Very Long User Name For Overflow Testing',
              userEmail: 'very.long.email.address@students.hku.hk',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.text('A Very Long User Name For Overflow Testing'),
      findsOneWidget,
    );
    expect(
      find.text('very.long.email.address@students.hku.hk'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('NotificationSection keeps reminder selector full width', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: NotificationSection(
              permissionGranted: true,
              enabled: true,
              reminderMinutes: 30,
              isBusy: false,
              onToggleEnabled: _noopToggle,
              onReminderMinutesChanged: _noopReminderChange,
            ),
          ),
        ),
      ),
    );

    final segmentedButton = find.byWidgetPredicate(
      (widget) => widget is SegmentedButton<int>,
    );
    final width = tester.getSize(segmentedButton).width;

    expect(width, closeTo(360 - (AppSpacing.lg * 2), 0.1));
  });

  testWidgets('LocationSection delegates permission action', (
    WidgetTester tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LocationSection(
            permission: LocationPermission.denied,
            isBusy: false,
            onPermissionAction: () async {
              tapped = true;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Allow'));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('ChatInputBar disables send when no session is available', (
    WidgetTester tester,
  ) async {
    final controller = TextEditingController(text: 'hello');
    final focusNode = FocusNode();

    addTearDown(() {
      controller.dispose();
      focusNode.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatInputBar(
            controller: controller,
            focusNode: focusNode,
            hasSession: false,
            isLoading: false,
            statusMessage: 'Reconnect first',
            onSend: (_) {},
          ),
        ),
      ),
    );

    final sendButton = tester.widget<IconButton>(find.byType(IconButton));
    expect(sendButton.onPressed, isNull);
    expect(find.text('Reconnect first'), findsOneWidget);
  });

  testWidgets('ReservationList empty state still supports refresh', (
    WidgetTester tester,
  ) async {
    var refreshed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReservationList(
            reservations: const <Reservation>[],
            emptyMessage: 'No reservations found.',
            onRefresh: () async {
              refreshed = true;
            },
            onViewMap: (_) async {},
            onCancel: (_) async {},
          ),
        ),
      ),
    );

    expect(find.byType(RefreshIndicator), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();

    expect(refreshed, isTrue);
  });
}

void _noopThemeChange(ThemeMode _) {}
Future<void> _noopToggle(bool _) async {}
Future<void> _noopReminderChange(int _) async {}
