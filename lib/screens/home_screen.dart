import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as maps;
import 'package:geolocator/geolocator.dart';
import '../services/places_service.dart';
import '../services/directions_service.dart';
import '../utils/map_style.dart';
import '../widgets/location_field.dart';
import './navigation_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late maps.GoogleMapController _mapController;

  // Colors and styles
  static const backgroundColor = Color(0xFF2A2A2A);
  static const buttonBackground = Color(0xFF232323);
  static const buttonHighlighted = Color(0xFF333333);
  static const accentColor = Color(0xFFE7E486);
  static const textActive = Color(0xFFF4F4F4);
  static const textInactive = Color(0x0ffa4aa4);

  static const maps.CameraPosition _initialPosition = maps.CameraPosition(
    target: maps.LatLng(40.7580, -73.9855),
    zoom: 14.0,
  );

  TextEditingController? _startTextController;
  TextEditingController? _destinationTextController;

  maps.LatLng? _startLatLng;
  maps.LatLng? _destinationLatLng;

  Set<maps.Polyline> _polylines = {};
  Set<maps.Marker> _markers = {};

  Future<void> _updateRoute() async {
    if (_startLatLng == null || _destinationLatLng == null) {
      print("Start or Destination LatLng is null.");
      return;
    }

    print("Fetching route from $_startLatLng to $_destinationLatLng...");

    final routePoints = await fetchRoutePolyline(_startLatLng!, _destinationLatLng!);

    if (routePoints.isNotEmpty) {
      print("Route Points: $routePoints");

      setState(() {
        _polylines = {
          maps.Polyline(
            polylineId: const maps.PolylineId('route'),
            points: routePoints,
            color: Colors.blue,
            width: 5,
          )
        };

        _markers = {
          maps.Marker(
            markerId: const maps.MarkerId('start'),
            position: _startLatLng!,
            infoWindow: const maps.InfoWindow(title: 'Start'),
          ),
          maps.Marker(
            markerId: const maps.MarkerId('destination'),
            position: _destinationLatLng!,
            infoWindow: const maps.InfoWindow(title: 'Destination'),
          ),
        };

        // Adjust camera to fit the route
        final bounds = _getBounds(routePoints);
        _mapController.animateCamera(
          maps.CameraUpdate.newLatLngBounds(bounds, 50),
        );
      });
    } else {
      print("No route points found.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Unable to fetch directions!")),
      );
    }
  }

  Future<void> _handleStartSelection(dynamic suggestion) async {
    if (suggestion == "Current Location") {
      final position = await Geolocator.getCurrentPosition();
      _startLatLng = maps.LatLng(position.latitude, position.longitude);
      // Text is already set by LocationField, no need to set it here
    } else {
      final prediction = suggestion;
      // No need to set text here, it's already done in LocationField
      final place = await getPlaceDetails(prediction.placeId);
      if (place != null && place.latLng != null) {
        _startLatLng = maps.LatLng(place.latLng!.lat, place.latLng!.lng);
      }
    }

    if (_startLatLng != null && _destinationLatLng != null) {
      await _updateRoute();
    }
  }

  Future<void> _handleDestinationSelection(dynamic suggestion) async {
    if (suggestion == "Current Location") {
      final position = await Geolocator.getCurrentPosition();
      _destinationLatLng = maps.LatLng(position.latitude, position.longitude);
    } else {
      final prediction = suggestion;
      final place = await getPlaceDetails(prediction.placeId);
      if (place != null && place.latLng != null) {
        _destinationLatLng = maps.LatLng(
          place.latLng!.lat,
          place.latLng!.lng,
        );
      }
    }

    if (_startLatLng != null && _destinationLatLng != null) {
      await _updateRoute();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        title: const Text("G1 Navigation", style: TextStyle(color: textActive)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
              LocationField(
              hintText: 'Enter starting location',
              prefixIcon: Icons.my_location,
              suggestionsCallback: getPlaceSuggestions, // Your suggestions method
              onSuggestionChosen: (suggestion, textController) async {
                _startTextController = textController;
                await _handleStartSelection(suggestion);
              },
            ),
                const SizedBox(height: 16.0),
                LocationField(
                  hintText: 'Enter destination location',
                  prefixIcon: Icons.my_location,
                  suggestionsCallback: getPlaceSuggestions, // Your suggestions method
                  onSuggestionChosen: (suggestion, textController) async {
                    _startTextController = textController;
                    await _handleDestinationSelection(suggestion);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: maps.GoogleMap(
              initialCameraPosition: _initialPosition,
              onMapCreated: (controller) {
                _mapController = controller;
                _mapController.setMapStyle(darkMapStyle);
              },
              polylines: _polylines,
              markers: _markers,
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: () async {
            if (_startLatLng != null && _destinationLatLng != null) {
              final steps = await fetchRouteSteps(_startLatLng!, _destinationLatLng!);

              if (steps.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => NavigationPage(
                      steps: steps,
                    ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Unable to fetch directions!")),
                );
              }
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Please set start and destination points!")),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: buttonBackground,
            foregroundColor: textActive,
            minimumSize: const Size.fromHeight(50),
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          ).copyWith(
            overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
              if (states.contains(WidgetState.pressed)) {
                return buttonHighlighted;
              }
              return null;
            }),
          ),
          child: const Text('Start Navigation', style: TextStyle(fontSize: 18)),
        ),
      ),
    );
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
}
