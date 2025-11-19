import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fahrplan/models/g1/navigation.dart';

class MapboxService {
  static const String _geocodingBaseUrl =
      'https://api.mapbox.com/geocoding/v5/mapbox.places';
  static const String _directionsBaseUrl =
      'https://api.mapbox.com/directions/v5/mapbox';

  Future<String?> _getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('mapbox_api_key');
  }

  /// Search for places using Mapbox Geocoding API
  Future<List<MapboxPlace>> searchPlaces(
    String query, {
    double? latitude,
    double? longitude,
  }) async {
    final apiKey = await _getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Mapbox API key not configured');
    }

    final proximity = (latitude != null && longitude != null)
        ? '&proximity=$longitude,$latitude'
        : '';

    final url = Uri.parse(
        '$_geocodingBaseUrl/${Uri.encodeComponent(query)}.json?access_token=$apiKey$proximity&limit=5');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final features = data['features'] as List;
      return features.map((f) => MapboxPlace.fromJson(f)).toList();
    } else {
      throw Exception('Failed to search places: ${response.body}');
    }
  }

  /// Get directions using Mapbox Directions API
  Future<MapboxRoute> getDirections({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    String profile = 'driving', // driving, walking, cycling
  }) async {
    final apiKey = await _getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Mapbox API key not configured');
    }

    final coordinates = '$startLng,$startLat;$endLng,$endLat';
    final url = Uri.parse(
        '$_directionsBaseUrl/$profile/$coordinates?access_token=$apiKey&steps=true&banner_instructions=true&geometries=geojson&overview=full');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final routes = data['routes'] as List;
      if (routes.isEmpty) {
        throw Exception('No routes found');
      }
      return MapboxRoute.fromJson(routes[0]);
    } else {
      throw Exception('Failed to get directions: ${response.body}');
    }
  }
}

class MapboxPlace {
  final String id;
  final String placeName;
  final double latitude;
  final double longitude;
  final String? address;

  MapboxPlace({
    required this.id,
    required this.placeName,
    required this.latitude,
    required this.longitude,
    this.address,
  });

  factory MapboxPlace.fromJson(Map<String, dynamic> json) {
    final center = json['center'] as List;
    return MapboxPlace(
      id: json['id'],
      placeName: json['place_name'],
      longitude: center[0].toDouble(),
      latitude: center[1].toDouble(),
      address: json['properties']?['address'],
    );
  }
}

class MapboxRoute {
  final double distance; // in meters
  final double duration; // in seconds
  final List<MapboxStep> steps;
  final List<List<double>> geometry; // route coordinates

  MapboxRoute({
    required this.distance,
    required this.duration,
    required this.steps,
    required this.geometry,
  });

  factory MapboxRoute.fromJson(Map<String, dynamic> json) {
    final legs = json['legs'] as List;
    final allSteps = <MapboxStep>[];

    for (var leg in legs) {
      final steps =
          (leg['steps'] as List).map((s) => MapboxStep.fromJson(s)).toList();
      allSteps.addAll(steps);
    }

    final geometryData = json['geometry']['coordinates'] as List;
    final geometry = geometryData
        .map((coord) =>
            [(coord[0] as num).toDouble(), (coord[1] as num).toDouble()])
        .toList();

    return MapboxRoute(
      distance: (json['distance'] as num).toDouble(),
      duration: (json['duration'] as num).toDouble(),
      steps: allSteps,
      geometry: geometry,
    );
  }
}

class MapboxStep {
  final double distance; // in meters
  final double duration; // in seconds
  final String instruction;
  final String? maneuverType;
  final String? maneuverModifier;
  final double? maneuverBearingAfter;

  MapboxStep({
    required this.distance,
    required this.duration,
    required this.instruction,
    this.maneuverType,
    this.maneuverModifier,
    this.maneuverBearingAfter,
  });

  factory MapboxStep.fromJson(Map<String, dynamic> json) {
    final maneuver = json['maneuver'];
    return MapboxStep(
      distance: (json['distance'] as num).toDouble(),
      duration: (json['duration'] as num).toDouble(),
      instruction: maneuver['instruction'] ?? '',
      maneuverType: maneuver['type'],
      maneuverModifier: maneuver['modifier'],
      maneuverBearingAfter: maneuver['bearing_after']?.toDouble(),
    );
  }

  /// Convert Mapbox maneuver to DirectionTurn constant
  int toDirectionTurn() {
    if (maneuverType == 'arrive') {
      return DirectionTurn.straight;
    }

    switch (maneuverModifier) {
      case 'uturn':
        return DirectionTurn.uTurnLeft;
      case 'sharp right':
        return DirectionTurn.strongRight;
      case 'right':
        return DirectionTurn.right;
      case 'slight right':
        return DirectionTurn.slightRight;
      case 'straight':
        return DirectionTurn.straight;
      case 'slight left':
        return DirectionTurn.slightLeft;
      case 'left':
        return DirectionTurn.left;
      case 'sharp left':
        return DirectionTurn.strongLeft;
      default:
        // Handle roundabouts and other cases
        if (maneuverType?.contains('roundabout') == true) {
          if (maneuverModifier?.contains('right') == true) {
            return DirectionTurn.rightLaneRightAtRoundabout;
          } else if (maneuverModifier?.contains('left') == true) {
            return DirectionTurn.rightLaneLeftAtRoundabout;
          }
          return DirectionTurn.rightLaneStraightAtRoundabout;
        }
        if (maneuverType == 'merge') {
          return DirectionTurn.merge;
        }
        if (maneuverType == 'off ramp') {
          if (maneuverModifier?.contains('right') == true) {
            return DirectionTurn.rightOfframp;
          }
          return DirectionTurn.leftOfframp;
        }
        if (maneuverType == 'fork') {
          if (maneuverModifier?.contains('right') == true) {
            return DirectionTurn.slightRightAtFork;
          }
          return DirectionTurn.slightLeftAtFork;
        }
        return DirectionTurn.straight;
    }
  }
}
