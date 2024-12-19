import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as maps;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';
import '../utils/route_step.dart';
import '../services/directions_service.dart';
import '../utils/map_style.dart';

class NavigationPage extends StatefulWidget {
  final List<RouteStep> steps;

  const NavigationPage({
    Key? key,
    required this.steps,
  }) : super(key: key);

  @override
  State<NavigationPage> createState() => _NavigationPageState();
}

class _NavigationPageState extends State<NavigationPage> {
  late maps.GoogleMapController _mapController;
  late StreamSubscription<Position> _locationSubscription;
  late StreamSubscription<CompassEvent> _headingSubscription;

  int _currentStepIndex = 0;
  maps.LatLng? _currentLocation;
  double _currentHeading = 0.0;
  List<maps.LatLng> _routePoints = [];
  bool _isRerouting = false;

  // Colors and styles
  static const backgroundColor = Color(0xFF2A2A2A);
  static const accentColor = Color(0xFFE7E486);
  static const textActive = Color(0xFFF4F4F4);
  static const textInactive = Color(0xFFA4A4A4);

  @override
  void initState() {
    super.initState();
    _fetchFullRoute();
    _startLocationTracking();
    _startCompassTracking();
  }

  Future<void> _fetchFullRoute() async {
    final start = widget.steps.first.location;
    final end = widget.steps.last.location;

    final polylinePoints = await fetchRoutePolyline(start, end);
    if (polylinePoints.isNotEmpty) {
      setState(() {
        _routePoints = polylinePoints;
      });

      if (_routePoints.isNotEmpty) {
        _mapController.animateCamera(
          maps.CameraUpdate.newLatLngBounds(_getBounds(_routePoints), 50),
        );
      }
    }
  }

  void _startLocationTracking() {
    _locationSubscription = Geolocator.getPositionStream().listen((Position position) {
      setState(() {
        _currentLocation = maps.LatLng(position.latitude, position.longitude);
      });

      _updateCurrentStep();

      if (_currentLocation != null && !_isRerouting) {
        _mapController.animateCamera(
          maps.CameraUpdate.newCameraPosition(
            maps.CameraPosition(
              target: _currentLocation!,
              zoom: 16.0,
              bearing: _currentHeading,
            ),
          ),
        );
      }
    });
  }

  void _startCompassTracking() {
    _headingSubscription = FlutterCompass.events?.listen((event) {
      setState(() {
        _currentHeading = event.heading ?? 0.0;
      });
    }) as StreamSubscription<CompassEvent>;
  }

  void _updateCurrentStep() {
    if (_currentLocation != null && _currentStepIndex < widget.steps.length) {
      final currentStep = widget.steps[_currentStepIndex];
      final distanceToNextStep = Geolocator.distanceBetween(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
        currentStep.location.latitude,
        currentStep.location.longitude,
      );

      if (distanceToNextStep < 20 && _currentStepIndex < widget.steps.length - 1) {
        setState(() {
          _currentStepIndex++;
        });
      }
    }
  }

  maps.LatLngBounds _getBounds(List<maps.LatLng> points) {
    double south = points.first.latitude;
    double west = points.first.longitude;
    double north = points.first.latitude;
    double east = points.first.longitude;

    for (var point in points) {
      south = min(south, point.latitude);
      west = min(west, point.longitude);
      north = max(north, point.latitude);
      east = max(east, point.longitude);
    }

    return maps.LatLngBounds(
      southwest: maps.LatLng(south, west),
      northeast: maps.LatLng(north, east),
    );
  }

  @override
  void dispose() {
    _locationSubscription.cancel();
    _headingSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        title: const Text("Navigation", style: TextStyle(color: textInactive)),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 1,
            child: ListView.builder(
              itemCount: widget.steps.length - _currentStepIndex,
              itemBuilder: (context, index) {
                final stepIndex = _currentStepIndex + index;
                final step = widget.steps[stepIndex];

                Color textColor;
                if (index == 0) {
                  textColor = accentColor;
                } else if (index == 1) {
                  textColor = textActive;
                } else {
                  textColor = textInactive;
                }

                return ListTile(
                  title: Text(
                    step.instruction,
                    style: TextStyle(color: textColor, fontSize: 18),
                  ),
                  subtitle: Text(
                    (step.additionalDetails.isNotEmpty
                        ? "${step.additionalDetails}\n"
                        : '') + step.distance,
                    style: const TextStyle(color: textInactive, fontSize: 14),
                  ),
                );
              },
            ),
          ),
          Expanded(
            flex: 2,
            child: maps.GoogleMap(
              initialCameraPosition: maps.CameraPosition(
                target: _routePoints.isNotEmpty ? _routePoints.first : const maps.LatLng(0, 0),
                zoom: 16.0,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
                _mapController.setMapStyle(darkMapStyle);
              },
              markers: {
                if (_currentLocation != null)
                  maps.Marker(
                    markerId: const maps.MarkerId('currentLocation'),
                    position: _currentLocation!,
                    icon: maps.BitmapDescriptor.defaultMarkerWithHue(
                      maps.BitmapDescriptor.hueBlue,
                    ),
                  ),
              },
              polylines: {
                if (_routePoints.isNotEmpty)
                  maps.Polyline(
                    polylineId: const maps.PolylineId('route'),
                    points: _routePoints,
                    color: Colors.blue,
                    width: 5,
                  ),
              },
              mapToolbarEnabled: false,
              zoomControlsEnabled: false,
            ),
          ),
        ],
      ),
    );
  }
}
