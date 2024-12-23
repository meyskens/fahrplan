import 'dart:async';
import 'package:google_maps_flutter/google_maps_flutter.dart' as maps;
import 'package:geolocator/geolocator.dart';
import '../services/directions_service.dart';
import '../utils/route_step.dart';

class NavigationService {
  final List<maps.LatLng> routePoints;
  final List<RouteStep> routeSteps;
  final Function(RouteStep step) onNextStep; // Callback when moving to the next step
  final Function() onRouteCompleted; // Callback when the route is completed
  final Function() onRerouting; // Callback for rerouting

  int _currentStepIndex = 0;
  StreamSubscription<Position>? _positionStream;

  NavigationService({
    required this.routePoints,
    required this.routeSteps,
    required this.onNextStep,
    required this.onRouteCompleted,
    required this.onRerouting,
  });

  void startNavigation() {
    _positionStream = Geolocator.getPositionStream().listen((Position position) {
      final userLocation = maps.LatLng(position.latitude, position.longitude);
      _checkProximityToNextStep(userLocation);
    });
  }

  void stopNavigation() {
    _positionStream?.cancel();
  }

  void _checkProximityToNextStep(maps.LatLng userLocation) {
    if (_currentStepIndex >= routePoints.length) {
      onRouteCompleted();
      stopNavigation();
      return;
    }

    final nextStep = routePoints[_currentStepIndex];
    final distanceToNextStep = Geolocator.distanceBetween(
      userLocation.latitude,
      userLocation.longitude,
      nextStep.latitude,
      nextStep.longitude,
    );

    if (distanceToNextStep < 20) { // e.g., 20 meters
      _currentStepIndex++;
      if (_currentStepIndex < routeSteps.length) {
        onNextStep(routeSteps[_currentStepIndex]);
      }
    }
  }

  Future<void> checkForRerouting(maps.LatLng userLocation) async {
    final nearestPoint = _findNearestPointOnPolyline(userLocation, routePoints);

    final distanceToPolyline = Geolocator.distanceBetween(
      userLocation.latitude,
      userLocation.longitude,
      nearestPoint.latitude,
      nearestPoint.longitude,
    );

    if (distanceToPolyline > 50) { // e.g., 50 meters
      onRerouting();

      // Recalculate the route
      final newRoutePoints = await fetchRoutePolyline(userLocation, routePoints.last);

      if (newRoutePoints.isNotEmpty) {
        routePoints.clear();
        routePoints.addAll(newRoutePoints);

        _currentStepIndex = 0;
      }
    }
  }

  maps.LatLng _findNearestPointOnPolyline(maps.LatLng userLocation, List<maps.LatLng> polyline) {
    maps.LatLng nearestPoint = polyline.first;
    double shortestDistance = double.infinity;

    for (var point in polyline) {
      final distance = Geolocator.distanceBetween(
        userLocation.latitude,
        userLocation.longitude,
        point.latitude,
        point.longitude,
      );

      if (distance < shortestDistance) {
        shortestDistance = distance;
        nearestPoint = point;
      }
    }

    return nearestPoint;
  }
}
