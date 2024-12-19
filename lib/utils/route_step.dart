import 'package:google_maps_flutter/google_maps_flutter.dart' as maps;

class RouteStep {
  final String instruction;
  final String additionalDetails;
  final String distance;
  final maps.LatLng location;

  RouteStep({
    required this.instruction,
    required this.additionalDetails,
    required this.distance,
    required this.location,
  });
}
