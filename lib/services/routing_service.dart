import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RoutingService {
  Future<List<Map<String, dynamic>>> getRoutes({
    required LatLng start,
    required LatLng destination,
  }) async {
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${start.longitude},${start.latitude};'
      '${destination.longitude},${destination.latitude}'
      '?alternatives=2&overview=full&geometries=geojson',
    );

    final response = await http.get(url);

    if (response.statusCode != 200) {
      throw Exception(
        'Routing request failed: ${response.statusCode}',
      );
    }

    final data = jsonDecode(response.body);

    if (data['code'] != 'Ok') {
      throw Exception('No route found.');
    }

    final routes = data['routes'] as List;

  return routes.map<Map<String, dynamic>>((route) {
    final coordinates = route['geometry']['coordinates'];

    final routePoints = coordinates.map<LatLng>((coordinate) {
      return LatLng(
        (coordinate[1] as num).toDouble(),
        (coordinate[0] as num).toDouble(),
      );
    }).toList();

    return {
      'points': routePoints,
      'distance': (route['distance'] as num).toDouble(),
      'duration': (route['duration'] as num).toDouble(),
    };
  }).toList();
  }
}