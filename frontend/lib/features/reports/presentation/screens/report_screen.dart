import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/ui/widgets/empty_state.dart';
import '../../../../core/ui/widgets/loading_state.dart';
import '../../../../theme/app_theme.dart';
import '../../../library/data/library_repository.dart';
import '../../data/report_repository.dart';
import '../controllers/report_controller.dart';
import '../widgets/occupancy_heatmap.dart';
import '../widgets/occupancy_trend_chart.dart';
import '../widgets/peak_hours_list.dart';
import '../widgets/report_filter_bar.dart';
import '../widgets/report_summary_cards.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  late final ReportController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ReportController(
      reportRepository: context.read<ReportRepository>(),
      libraryRepository: context.read<LibraryRepository>(),
    );
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return ChangeNotifierProvider<ReportController>.value(
      value: _controller,
      child: Consumer<ReportController>(
        builder: (context, controller, child) {
          final dashboard = controller.dashboard;

          if (controller.isLoading && dashboard == null) {
            return const LoadingState(message: 'Loading insights...');
          }

          if (controller.libraries.isEmpty && controller.hasError) {
            return EmptyState(
              icon: Icons.error_outline,
              title: 'Could not load insights',
              message: controller.errorMessage,
              action: ElevatedButton(
                onPressed: controller.initialize,
                child: const Text('Retry'),
              ),
            );
          }

          if (controller.libraries.isEmpty) {
            return const EmptyState(
              icon: Icons.local_library_outlined,
              title: 'No libraries found',
              message: 'Insights will appear when libraries are available.',
            );
          }

          if (controller.hasError && dashboard == null) {
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                ReportFilterBar(
                  libraries: controller.libraries,
                  selectedLocation: controller.selectedLocation,
                  isLoading: controller.isLoading,
                  onLocationChanged: controller.selectLocation,
                ),
                const SizedBox(height: AppSpacing.xl),
                EmptyState(
                  icon: Icons.error_outline,
                  title: 'Could not load insights',
                  message: controller.errorMessage,
                  action: ElevatedButton(
                    onPressed: controller.refresh,
                    child: const Text('Retry'),
                  ),
                ),
              ],
            );
          }

          return RefreshIndicator(
            onRefresh: controller.refresh,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                ReportFilterBar(
                  libraries: controller.libraries,
                  selectedLocation: controller.selectedLocation,
                  isLoading: controller.isLoading,
                  onLocationChanged: controller.selectLocation,
                ),
                if (controller.hasError && dashboard != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  MaterialBanner(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    content: Text(controller.errorMessage ?? 'Refresh failed'),
                    leading: Icon(Icons.error_outline, color: cs.error),
                    actions: [
                      TextButton(
                        onPressed: controller.clearError,
                        child: const Text('Dismiss'),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Historical Insights',
                  style: tt.titleLarge?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Plan around quieter hours and weekly traffic patterns.',
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (dashboard == null)
                  const EmptyState(
                    icon: Icons.insights_outlined,
                    title: 'No insights yet',
                    message: 'Choose a library to view historical occupancy.',
                  )
                else if (!dashboard.summary.hasData)
                  EmptyState(
                    icon: Icons.query_stats_outlined,
                    title: 'No historical data yet',
                    message:
                        'No historical occupancy snapshots have been collected for ${controller.selectedLocation} in this window.',
                  )
                else ...[
                  ReportSummaryCards(summary: dashboard.summary),
                  const SizedBox(height: AppSpacing.xl),
                  OccupancyTrendChart(
                    trend: dashboard.trend,
                    selectedDays: controller.trendDays,
                    isLoading: controller.isTrendLoading,
                    onDaysChanged: controller.selectTrendDays,
                  ),
                  if (controller.hasTrendError) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      controller.trendErrorMessage ?? 'Trend refresh failed',
                      style: tt.bodySmall?.copyWith(color: cs.error),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  OccupancyHeatmap(heatmap: dashboard.heatmap),
                  const SizedBox(height: AppSpacing.xl),
                  PeakHoursList(peakHours: dashboard.peakHours),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
