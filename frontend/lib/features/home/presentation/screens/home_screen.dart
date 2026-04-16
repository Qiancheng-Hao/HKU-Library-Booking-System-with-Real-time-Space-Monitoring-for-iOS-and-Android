import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../providers/auth_provider.dart';
import '../widgets/best_spot_card.dart';
import '../widgets/greeting_header.dart';
import '../widgets/live_occupancy_list.dart';
import '../../../../theme/app_theme.dart';
import '../../data/occupancy_repository.dart';
import '../controllers/home_controller.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeController _controller;

  @override
  void initState() {
    super.initState();
    _controller = HomeController(
      occupancyRepository: context.read<OccupancyRepository>(),
    );
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 18) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return ChangeNotifierProvider<HomeController>.value(
      value: _controller,
      child: Consumer2<HomeController, AuthProvider>(
        builder: (context, controller, auth, child) {
          return Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.lg),
                    GreetingHeader(
                      greeting: _getGreeting(),
                      userName: auth.userName ?? 'User',
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    BestSpotCard(
                      recommendation: controller.recommendation,
                      isLoading:
                          controller.isLoading ||
                          controller.isRecommendationLoading,
                      errorMessage: controller.recommendationErrorMessage,
                      strategy: controller.recommendationStrategy,
                      onStrategyChanged: controller.changeStrategy,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Live Occupancy',
                          style: tt.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: cs.primary,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.refresh, color: cs.primary),
                          onPressed: controller.isLoading
                              ? null
                              : controller.refresh,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Expanded(
                      child: LiveOccupancyList(
                        snapshot: controller.occupancy,
                        isLoading: controller.isLoading,
                        errorMessage: controller.errorMessage,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
