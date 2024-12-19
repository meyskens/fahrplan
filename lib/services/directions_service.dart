import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart' as maps;
import 'package:http/http.dart' as http;
import '../utils/polyline_decoder.dart';
import '../utils/route_step.dart'; // Import RouteStep here

const directionsApiKey = 'AIzaSyDNkyfweMy-wKaBHjMjDWT8IDx4pWXBo0g';

Future<List<maps.LatLng>> fetchRoutePolyline(maps.LatLng start, maps.LatLng end) async {
  final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json?origin=${start.latitude},${start.longitude}&destination=${end.latitude},${end.longitude}&key=$directionsApiKey');

  final response = await http.get(url);

  if (response.statusCode == 200) {
    final data = json.decode(response.body);

    if (data['routes'].isNotEmpty) {
      final polyline = data['routes'][0]['overview_polyline']['points'];
      print("Overview Polyline: $polyline");

      return decodePolyline(polyline); // Decode the polyline into LatLng points
    } else {
      print("No routes found in API response.");
    }
  } else {
    print("Failed to fetch directions. Status code: ${response.statusCode}");
  }

  return [];
}

Future<List<RouteStep>> fetchRouteSteps(maps.LatLng start, maps.LatLng end) async {
  final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json?origin=${start.latitude},${start.longitude}&destination=${end.latitude},${end.longitude}&key=$directionsApiKey'
  );

  final response = await http.get(url);
  if (response.statusCode == 200) {
    final data = json.decode(response.body);

    if (data['routes'].isNotEmpty) {
      final steps = data['routes'][0]['legs'][0]['steps'] as List;

      return steps.map((step) {
        final instruction = step['html_instructions'] as String;
        final parts = instruction.split('<div'); // Split at <div>
        final mainInstruction = parts.first.replaceAll(RegExp(r'<[^>]*>'), ''); // First part without HTML tags
        final additionalDetails = parts.length > 1
            ? parts[1].replaceAll(RegExp(r'<[^>]*>|style="[^"]*"'), '').trim() // Second part, clean and trimmed
            : ''; // Default to empty if no additional details
        final distance = step['distance']['text'] as String;
        final location = maps.LatLng(
          step['end_location']['lat'],
          step['end_location']['lng'],
        );
        return RouteStep(
          instruction: mainInstruction,
          additionalDetails: additionalDetails,
          distance: distance,
          location: location,
        );
      }).toList();
    }
  }
  return [];
}
