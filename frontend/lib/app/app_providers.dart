import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/di/app_services.dart';
import '../features/ai_agent/data/ai_agent_repository.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/home/data/occupancy_repository.dart';
import '../features/library/data/library_repository.dart';
import '../features/library/data/reservation_repository.dart';
import '../features/reports/data/report_repository.dart';
import '../providers/ai_session_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/theme_provider.dart';

class AppProviders extends StatelessWidget {
  final Widget child;

  const AppProviders({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthRepository>.value(value: AppServices.authRepository),
        Provider<AiAgentRepository>.value(value: AppServices.aiAgentRepository),
        Provider<LibraryRepository>.value(value: AppServices.libraryRepository),
        Provider<ReservationRepository>.value(
          value: AppServices.reservationRepository,
        ),
        Provider<OccupancyRepository>.value(
          value: AppServices.occupancyRepository,
        ),
        Provider<ReportRepository>.value(value: AppServices.reportRepository),
        ChangeNotifierProvider(
          create: (context) =>
              AuthProvider(authRepository: context.read<AuthRepository>()),
        ),
        ChangeNotifierProvider(
          create: (context) => AiSessionProvider(
            aiAgentRepository: context.read<AiAgentRepository>(),
          ),
        ),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: child,
    );
  }
}
