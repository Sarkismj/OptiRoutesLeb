import '../services/routing_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'vehicle_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/location_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final LocationService locationService = LocationService();
  final MapController mapController = MapController();
  final RoutingService routingService = RoutingService();

  List<Map<String, dynamic>> locations = [];
  bool isLoading = true;
  LatLng? userLocation;
  Map<String, dynamic>? selectedDestination;
  List<LatLng> routePoints = [];
  List<Map<String, dynamic>> availableRoutes = [];
  String routeMode = 'Balanced';

  double? routeDistance;
  double? routeDuration;
  double? fuelConsumption;
  double? fuelPrice;

  @override
  void initState() {
    super.initState();
    loadLocations();
    getUserLocation();
    loadVehicle();
  }

  Future<void> loadVehicle() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      return;
    }

    final vehicle = await Supabase.instance.client
        .from('vehicles')
        .select('fuel_consumption, fuel_price')
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (vehicle == null) {
      return;
    }

    print('Vehicle loaded: $vehicle');

    setState(() {
      fuelConsumption =
          (vehicle['fuel_consumption'] as num).toDouble();

      fuelPrice =
          (vehicle['fuel_price'] as num).toDouble();
    });
  }

  Future<void> loadLocations() async {
    try {
      final data = await locationService.getLocations();

      setState(() {
        locations = data;
        isLoading = false;
      });
    } catch (error) {
      print('Error loading locations: $error');

      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> getUserLocation() async {
    print('LOCATION: Starting...');

    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();

    print('LOCATION: Service enabled = $serviceEnabled');

    if (!serviceEnabled) {
      print('LOCATION: Location service is OFF');
      return;
    }

    permission = await Geolocator.checkPermission();

    print('LOCATION: Permission = $permission');

    if (permission == LocationPermission.denied) {
      print('LOCATION: Requesting permission...');

      permission = await Geolocator.requestPermission();

      print('LOCATION: Permission after request = $permission');

      if (permission == LocationPermission.denied) {
        print('LOCATION: Permission DENIED');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print('LOCATION: Permission DENIED FOREVER');
      return;
    }

    print('LOCATION: Getting GPS position...');

    final position = await Geolocator.getCurrentPosition();

    print(
      'LOCATION SUCCESS: ${position.latitude}, ${position.longitude}',
    );

    if (!mounted) return;

    setState(() {
      userLocation = LatLng(
        position.latitude,
        position.longitude,
      );
    });
  }

  Map<String, dynamic> calculateRouteStats(
    Map<String, dynamic> route,
  ) {
    final distanceKm =
        (route['distance'] as num).toDouble() / 1000;

    final durationMinutes =
        (route['duration'] as num).toDouble() / 60;

    double? fuel;
    double? cost;

    if (fuelConsumption != null && fuelPrice != null) {
      fuel = distanceKm * fuelConsumption! / 100;
      cost = fuel * fuelPrice!;
    }

    return {
      'distanceKm': distanceKm,
      'durationMinutes': durationMinutes,
      'fuel': fuel,
      'cost': cost,
    };
  }


  double calculateBalancedScore(
    Map<String, dynamic> route,
    List<Map<String, dynamic>> routes,
  ) {
    final stats = calculateRouteStats(route);

    final distance = stats['distanceKm'] as double;
    final duration = stats['durationMinutes'] as double;
    final fuel = (stats['fuel'] as double?) ?? distance;

    final distances = routes.map(
      (r) => calculateRouteStats(r)['distanceKm'] as double,
    );

    final durations = routes.map(
      (r) => calculateRouteStats(r)['durationMinutes'] as double,
    );

    final fuels = routes.map(
      (r) => (calculateRouteStats(r)['fuel'] as double?) ?? 
          (calculateRouteStats(r)['distanceKm'] as double),
    );

    final minDistance = distances.reduce(
      (a, b) => a < b ? a : b,
    );

    final maxDistance = distances.reduce(
      (a, b) => a > b ? a : b,
    );

    final minDuration = durations.reduce(
      (a, b) => a < b ? a : b,
    );

    final maxDuration = durations.reduce(
      (a, b) => a > b ? a : b,
    );

    final minFuel = fuels.reduce(
      (a, b) => a < b ? a : b,
    );

    final maxFuel = fuels.reduce(
      (a, b) => a > b ? a : b,
    );

    final distanceScore =
        maxDistance == minDistance
            ? 0.0
            : (distance - minDistance) /
                (maxDistance - minDistance);

    final durationScore =
        maxDuration == minDuration
            ? 0.0
            : (duration - minDuration) /
                (maxDuration - minDuration);

    final fuelScore =
        maxFuel == minFuel
            ? 0.0
            : (fuel - minFuel) /
                (maxFuel - minFuel);

    return
        distanceScore * 0.30 +
        durationScore * 0.40 +
        fuelScore * 0.30;
  }


  Map<String, dynamic> chooseBestRoute(
    List<Map<String, dynamic>> routes,
  ) {
    if (routes.isEmpty) {
      throw Exception('No routes available.');
    }

    if (routeMode == 'Fastest') {
      return routes.reduce(
        (a, b) =>
            (a['duration'] as num) < (b['duration'] as num)
                ? a
                : b,
      );
    }

    if (routeMode == 'Cheapest') {
      if (fuelConsumption == null || fuelPrice == null) {
        return routes.reduce(
          (a, b) =>
              (a['distance'] as num) < (b['distance'] as num)
                  ? a
                  : b,
        );
      }

      return routes.reduce((a, b) {
        final fuelA =
            ((a['distance'] as num).toDouble() / 1000) *
                fuelConsumption! /
                100;

        final fuelB =
            ((b['distance'] as num).toDouble() / 1000) *
                fuelConsumption! /
                100;

        return fuelA < fuelB ? a : b;
      });
    }

  // Balanced:
  // Give equal importance to time and distance.
  final maxDistance = routes
      .map((r) => (r['distance'] as num).toDouble())
      .reduce((a, b) => a > b ? a : b);

  final maxDuration = routes
      .map((r) => (r['duration'] as num).toDouble())
      .reduce((a, b) => a > b ? a : b);

  return routes.reduce((a, b) {
    final scoreA =
        ((a['distance'] as num).toDouble() / maxDistance) +
        ((a['duration'] as num).toDouble() / maxDuration);

    final scoreB =
        ((b['distance'] as num).toDouble() / maxDistance) +
        ((b['duration'] as num).toDouble() / maxDuration);

    return scoreA < scoreB ? a : b;
  });
}

void applyRouteMode() {
  if (availableRoutes.isEmpty) {
    return;
  }

  final bestRoute = chooseBestRoute(availableRoutes);

  setState(() {
    routePoints =
        List<LatLng>.from(bestRoute['points']);

    routeDistance =
        (bestRoute['distance'] as num).toDouble();

    routeDuration =
        (bestRoute['duration'] as num).toDouble();
  });
}




  @override
  Widget build(BuildContext context) {
    double? estimatedFuel;
    double? estimatedFuelCost;

    if (routeDistance != null && fuelConsumption != null && fuelPrice != null) {
      estimatedFuel = (routeDistance! / 1000) * fuelConsumption! / 100;
      estimatedFuelCost = estimatedFuel * fuelPrice!;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('OptiRoutesNorth'),

        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const VehicleScreen(),
                ),
              );
            },
            icon: const Icon(Icons.directions_car),
            tooltip: 'My Vehicle',
          ),
        ],
      ),

      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Stack(
              children: [
                FlutterMap(
                  mapController: mapController,

                  options: MapOptions(
                    initialCenter: const LatLng(34.4367, 35.8497),
                    initialZoom: 11,

                    minZoom: 10,
                    maxZoom: 18,

                    cameraConstraint: CameraConstraint.contain(
                      bounds: LatLngBounds(
                        const LatLng(34.15, 35.55), // Southwest
                        const LatLng(34.55, 36.15), // Northeast
                      ),
                    ),
                  ),

                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName:
                          'com.example.opti_routes_leb',
                    ),

                    if (routePoints.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: routePoints,
                            strokeWidth: 6,
                          ),
                        ],
                      ),
                    // Supabase locations
                    MarkerLayer(
                      markers: locations.map((location) {
                        final latitude =
                            (location['latitude'] as num).toDouble();

                        final longitude =
                            (location['longitude'] as num).toDouble();

                        return Marker(
                          point: LatLng(
                            latitude,
                            longitude,
                          ),
                          width: 60,
                          height: 60,

                          child: GestureDetector(
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                builder: (context) {
                                  return Padding(
                                    padding:
                                        const EdgeInsets.all(20),

                                    child: Column(
                                      mainAxisSize:
                                          MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,

                                      children: [
                                        Text(
                                          location['name'] ??
                                              'Unknown location',
                                          style:
                                              const TextStyle(
                                            fontSize: 22,
                                            fontWeight:
                                                FontWeight.bold,
                                          ),
                                        ),

                                        const SizedBox(height: 8),

                                        Text(
                                          'Category: '
                                          '${location['category'] ?? 'Unknown'}',
                                        ),

                                        const SizedBox(height: 8),

                                        Text(
                                          location['description'] ??
                                              'No description available',
                                        ),

                                        const SizedBox(height: 8),

                                        Text(
                                          'Address: '
                                          '${location['address'] ?? 'Not available'}',
                                        ),
                                        
                                        const SizedBox(height: 20),

                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton.icon(
                                              onPressed: () async {
                                                setState(() {
                                                  selectedDestination = location;
                                                });

                                                Navigator.pop(context);

                                                if (userLocation == null) {
                                                  print('User location is not available.');
                                                  return;
                                                }

                                                final destination = LatLng(
                                                  (location['latitude'] as num).toDouble(),
                                                  (location['longitude'] as num).toDouble(),
                                                );

                                                try {
                                                  final routes = await routingService.getRoutes(
                                                    start: userLocation!,
                                                    destination: destination,
                                                  );

                                                  setState(() {
                                                    availableRoutes = routes;
                                                  });

                                                  applyRouteMode();

                                                  print('ROUTES SUCCESS!');
                                                  print('Number of routes: ${routes.length}');

                                                  for (int i = 0; i < routes.length; i++) {
                                                    final stats = calculateRouteStats(routes[i]);
                                                    print(
                                                      'Route ${i + 1}: '
                                                      '${stats['distanceKm'].toStringAsFixed(1)} km, '
                                                      '${stats['durationMinutes'].round()} min, '
                                                      '${stats['fuel']?.toStringAsFixed(2) ?? 'N/A'} L, '
                                                      '\$${stats['cost']?.toStringAsFixed(2) ?? 'N/A'}',
                                                    );
                                                  }
                                                } catch (error) {
                                                  print('ROUTES ERROR: $error');
                                                }
                                              },
                                              icon: const Icon(Icons.navigation),
                                              label: const Text('Navigate Here'),
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },

                            child: const Icon(
                              Icons.location_pin,
                              size: 50,
                              color: Colors.red,
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    // User's current location
                    if (userLocation != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: userLocation!,
                            width: 50,
                            height: 50,
                            child: const Icon(
                              Icons.my_location,
                              size: 35,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                if (selectedDestination != null)
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 100,
                    child: Card(
                      elevation: 6,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 32,
                            ),

                            const SizedBox(width: 12),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'Destination',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),

                                  const SizedBox(height: 4),

                                  Text(
                                    selectedDestination!['name'] ??
                                        'Unknown location',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),

                                  Text(
                                    selectedDestination!['category'] ??
                                        'Unknown category',
                                  ),
                                  if (routeDistance != null && routeDuration != null) ...[
                                    const SizedBox(height: 12),

                                    const SizedBox(height: 12),
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: [
                                          ChoiceChip(
                                            label: const Text('⚡ Fastest'),
                                            selected: routeMode == 'Fastest',
                                            onSelected: (_) {
                                              setState(() {
                                                routeMode = 'Fastest';
                                              });

                                              applyRouteMode();
                                            },
                                          ),

                                          const SizedBox(width: 8),

                                          ChoiceChip(
                                            label: const Text('⛽ Cheapest'),
                                            selected: routeMode == 'Cheapest',
                                            onSelected: (_) {
                                              setState(() {
                                                routeMode = 'Cheapest';
                                              });

                                              applyRouteMode();
                                            },
                                          ),

                                          const SizedBox(width: 8),

                                          ChoiceChip(
                                            label: const Text('⚖️ Balanced'),
                                            selected: routeMode == 'Balanced',
                                            onSelected: (_) {
                                              setState(() {
                                                routeMode = 'Balanced';
                                              });

                                              applyRouteMode();
                                            },
                                          ),
                                        ],
                                      ),
                                    ),

                                    Text(
                                      '${(routeDistance! / 1000).toStringAsFixed(1)} km',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),

                                    Text(
                                      '~${(routeDuration! / 60).round()} min',
                                      style: const TextStyle(
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                  if (estimatedFuel != null && estimatedFuelCost != null) ...[
                                    const SizedBox(height: 8),

                                     Text(
                                      '⛽ Estimated fuel: '
                                      '${estimatedFuel.toStringAsFixed(2)} L',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '💰 Estimated fuel cost: '
                                      '\$${estimatedFuelCost.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            IconButton(
                              onPressed: () {
                                setState(() {
                                  selectedDestination = null;
                                  routePoints = [];
                                  routeDistance = null;
                                  routeDuration = null;
                                });
                              },
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                // Locate Me button
                Positioned(
                  right: 20,
                  bottom: 20,
                  child: FloatingActionButton(
                    onPressed: () {
                      if (userLocation != null) {
                        mapController.move(
                          userLocation!,
                          14,
                        );
                      }
                    },
                    child: const Icon(
                      Icons.my_location,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}