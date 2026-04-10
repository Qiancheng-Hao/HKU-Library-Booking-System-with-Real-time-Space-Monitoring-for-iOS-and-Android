import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ignore: unused_field
  String _locationMessage = "Fetching location...";
  Position? _currentPosition;
  late Future<Map<String, dynamic>> _occupancyFuture;
  late Future<Map<String, dynamic>> _recommendationFuture;
  String _recommendationStrategy = 'occupancyRate';

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _occupancyFuture = ApiService.getRealtimeOccupancy();
    _recommendationFuture = _fetchRecommendation();
  }

  Future<Map<String, dynamic>> _fetchRecommendation() {
    return ApiService.getOccupancyRecommendation(
      latitude: _currentPosition?.latitude,
      longitude: _currentPosition?.longitude,
      strategy: _recommendationStrategy,
    );
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!mounted) return;
    if (!serviceEnabled) {
      setState(() => _locationMessage = "Location services are disabled.");
      return;
    }

    permission = await Geolocator.checkPermission();
    if (!mounted) return;
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (!mounted) return;
      if (permission == LocationPermission.denied) {
        setState(() => _locationMessage = "Location permissions are denied");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(
        () => _locationMessage =
            "Location permissions are permanently denied, we cannot request permissions.",
      );
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      setState(() {
        _currentPosition = position;
        _locationMessage =
            "Lat: ${position.latitude}, Long: ${position.longitude}";
        _occupancyFuture = ApiService.getRealtimeOccupancy(
          latitude: position.latitude,
          longitude: position.longitude,
        );
        _recommendationFuture = _fetchRecommendation();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _locationMessage = "Error fetching location: $e");
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 18) return 'Good Afternoon';
    return 'Good Evening';
  }

  Future<void> _refreshOccupancy() async {
    if (!mounted) return;
    setState(() {
      _occupancyFuture = ApiService.getRealtimeOccupancy(
        latitude: _currentPosition?.latitude,
        longitude: _currentPosition?.longitude,
      );
      _recommendationFuture = _fetchRecommendation();
    });
    await Future.wait([_occupancyFuture, _recommendationFuture]);
  }

  void _changeStrategy(String newStrategy) {
    if (_recommendationStrategy != newStrategy) {
      setState(() {
        _recommendationStrategy = newStrategy;
        _recommendationFuture = _fetchRecommendation();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        final userName = auth.userName ?? 'User';
        final greeting = _getGreeting();

        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.lg),
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
                  const SizedBox(height: AppSpacing.xl),

                  // Best Spot Card
                  FutureBuilder<Map<String, dynamic>>(
                    future: _recommendationFuture,
                    builder: (context, snapshot) {
                      Widget content;

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        content = const Center(
                          child: CircularProgressIndicator(),
                        );
                      } else if (snapshot.hasError ||
                          !snapshot.hasData ||
                          snapshot.data!.isEmpty) {
                        content = Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 40,
                              color: cs.onSurfaceVariant,
                            ),
                            const SizedBox(width: AppSpacing.lg),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "No Recommendation",
                                    style: tt.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    "Check open hours or try again later.",
                                    style: tt.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      } else {
                        final data = snapshot.data!;
                        String libraryName = data['libraryName'].toString();
                        if (libraryName == 'Chi Wah Learning Commons') {
                          libraryName = 'Chi Wah Learning\nCommons';
                        }
                        final area = data['area'];
                        final occupancyRate = (data['occupancyRate'] as num)
                            .toDouble()
                            .clamp(0.0, 100.0);
                        final percentage = occupancyRate.toStringAsFixed(1);
                        final distance = (data['distanceFromUser'] as num)
                            .toDouble();

                        content = Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: Color(0xFFFFB300),
                              size: 44,
                            ),
                            const SizedBox(width: AppSpacing.lg),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Best Study Spot (${_recommendationStrategy == 'occupancyRate' ? 'Quietest' : 'Closest'})",
                                    style: tt.labelLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: cs.primary,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    "$libraryName\n$area",
                                    style: tt.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    "$percentage% Occupied • ${distance.toStringAsFixed(0)}m away",
                                    style: tt.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }

                      return Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            decoration: BoxDecoration(
                              color: cs.primaryContainer.withValues(
                                alpha: 0.35,
                              ),
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              border: Border.all(
                                color: cs.primary.withValues(alpha: 0.25),
                              ),
                            ),
                            child: content,
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: PopupMenuButton<String>(
                              icon: Icon(Icons.tune, color: cs.primary),
                              onSelected: _changeStrategy,
                              itemBuilder: (_) => [
                                const PopupMenuItem<String>(
                                  value: 'occupancyRate',
                                  child: Text('Prioritize Quietest'),
                                ),
                                const PopupMenuItem<String>(
                                  value: 'distance',
                                  child: Text('Prioritize Closest'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Live Occupancy",
                        style: tt.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.primary,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.refresh, color: cs.primary),
                        onPressed: _refreshOccupancy,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  Expanded(
                    child: FutureBuilder<Map<String, dynamic>>(
                      future: _occupancyFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        } else if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Error: ${snapshot.error}',
                              style: TextStyle(color: cs.error),
                            ),
                          );
                        } else if (!snapshot.hasData ||
                            (snapshot.data!['libraries'] as List).isEmpty) {
                          return const EmptyState(
                            icon: Icons.insights_outlined,
                            title: 'No live data yet',
                            message:
                                'Real-time occupancy will appear here as soon as it\'s available.',
                          );
                        }

                        final items = snapshot.data!['libraries'] as List;
                        return ListView.builder(
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final occupancyRate = (item['occupancyRate'] as num)
                                .toDouble()
                                .clamp(0.0, 100.0);
                            final percentage = occupancyRate.toStringAsFixed(1);
                            final isCrowded = occupancyRate > 70;
                            final isModerate =
                                occupancyRate > 30 && occupancyRate <= 70;

                            final Color statusColor;
                            final String statusText;
                            if (isCrowded) {
                              statusColor = AppColors.statusBusy;
                              statusText = "Busy";
                            } else if (isModerate) {
                              statusColor = AppColors.statusModerate;
                              statusText = "Moderate";
                            } else {
                              statusColor = AppColors.statusAvailable;
                              statusText = "Quiet";
                            }

                            String libraryName =
                                (item['libraryName'] ?? 'Unknown').toString();
                            if (libraryName == 'Chi Wah Learning Commons') {
                              libraryName = 'Chi Wah Learning\nCommons';
                            }

                            return Card(
                              margin: const EdgeInsets.only(
                                bottom: AppSpacing.md,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.lg),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 4,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: statusColor,
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.sm,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.lg),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            libraryName,
                                            style: tt.titleMedium,
                                          ),
                                          Text(
                                            item['area'] ?? '',
                                            style: tt.bodySmall?.copyWith(
                                              color: cs.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          "$percentage%",
                                          style: tt.titleLarge?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: statusColor,
                                          ),
                                        ),
                                        Text(
                                          statusText,
                                          style: tt.labelSmall?.copyWith(
                                            color: statusColor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
