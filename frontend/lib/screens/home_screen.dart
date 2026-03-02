import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _locationMessage = "Fetching location...";
  Position? _currentPosition;
  late Future<Map<String, dynamic>> _occupancyFuture;
  late Future<Map<String, dynamic>> _recommendationFuture;
  String _recommendationStrategy = 'occupancyRate'; // Default: Quietest

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

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _locationMessage = "Location services are disabled.";
      });
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _locationMessage = "Location permissions are denied";
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _locationMessage =
            "Location permissions are permanently denied, we cannot request permissions.";
      });
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
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
      setState(() {
        _locationMessage = "Error fetching location: $e";
      });
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 18) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  Future<void> _refreshOccupancy() async {
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
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        final userName = auth.userName ?? 'User';
        final greeting = _getGreeting();

        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Text(
                    greeting,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w300,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    userName,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(height: 20),

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
                            const Icon(
                              Icons.error_outline,
                              size: 40,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "No Recommendation",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    "Check open hours or try again later.",
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 13,
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
                            .toDouble();
                        final percentage = occupancyRate.toStringAsFixed(1);
                        final distance = (data['distanceFromUser'] as num)
                            .toDouble();

                        content = Row(
                          children: [
                            const Icon(
                              Icons.recommend,
                              color: Colors.teal,
                              size: 40,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Best Study Spot (${_recommendationStrategy == 'occupancyRate' ? 'Quietest' : 'Closest'})",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.teal,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "$libraryName\n$area",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "$percentage% Occupied • ${distance.toStringAsFixed(0)}m away",
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: 13,
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
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.teal.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.teal.withValues(alpha: 0.3),
                              ),
                            ),
                            child: content,
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: PopupMenuButton<String>(
                              icon: const Icon(Icons.tune, color: Colors.teal),
                              onSelected: _changeStrategy,
                              itemBuilder: (BuildContext context) =>
                                  <PopupMenuEntry<String>>[
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
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Live Occupancy",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.teal),
                        onPressed: _refreshOccupancy,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
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
                              style: const TextStyle(color: Colors.red),
                            ),
                          );
                        } else if (!snapshot.hasData ||
                            (snapshot.data!['libraries'] as List).isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 60,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No real-time data available yet.',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          );
                        }

                        final items = snapshot.data!['libraries'] as List;

                        return ListView.builder(
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final occupancyRate = (item['occupancyRate'] as num)
                                .toDouble();
                            final percentage = occupancyRate.toStringAsFixed(1);
                            final isCrowded = occupancyRate > 70;
                            final isModerate =
                                occupancyRate > 30 && occupancyRate <= 70;

                            Color statusColor;
                            String statusText;

                            if (isCrowded) {
                              statusColor = Colors.red;
                              statusText = "Busy";
                            } else if (isModerate) {
                              statusColor = Colors.orange;
                              statusText = "Moderate";
                            } else {
                              statusColor = Colors.green;
                              statusText = "Quiet";
                            }

                            String libraryName =
                                (item['libraryName'] ?? 'Unknown').toString();
                            if (libraryName == 'Chi Wah Learning Commons') {
                              libraryName = 'Chi Wah Learning\nCommons';
                            }

                            return Card(
                              elevation: 2,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: statusColor,
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            libraryName,
                                            style: const TextStyle(
                                              fontSize: 16,
                                            ),
                                          ),
                                          Text(
                                            item['area'] ?? '',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[600],
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
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: statusColor,
                                          ),
                                        ),
                                        Text(
                                          statusText,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: statusColor,
                                            fontWeight: FontWeight.w500,
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
