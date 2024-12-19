import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as maps;
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart' as places_sdk;
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

final places = places_sdk.FlutterGooglePlacesSdk('AIzaSyDNkyfweMy-wKaBHjMjDWT8IDx4pWXBo0g');
const directionsApiKey = 'AIzaSyDNkyfweMy-wKaBHjMjDWT8IDx4pWXBo0g';

const String _darkMapStyle = '''
[
  {
    "elementType": "geometry",
    "stylers": [
      { "color": "#2A2A2A" }  // Overall map background
    ]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [
      { "color": "#2A2A2A" }  // Text stroke matches background for cleaner text
    ]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [
      { "color": "#F4F4F4" }  // Default text color (active text)
    ]
  },
  {
    "featureType": "administrative",
    "elementType": "labels.text.fill",
    "stylers": [
      { "color": "#E7E486" }  // Accent color for administrative labels (e.g., city names)
    ]
  },
  {
    "featureType": "poi",
    "elementType": "geometry",
    "stylers": [
      { "color": "#232323" }  // POI background matches button background
    ]
  },
  {
    "featureType": "poi",
    "elementType": "labels.text.fill",
    "stylers": [
      { "color": "#A4A4A4" }  // POI labels use inactive text color for subtlety
    ]
  },
  {
    "featureType": "road",
    "elementType": "geometry",
    "stylers": [
      { "color": "#232323" }  // Roads use button background
    ]
  },
  {
    "featureType": "road",
    "elementType": "labels.text.fill",
    "stylers": [
      { "color": "#F4F4F4" }  // Road labels remain active text color for readability
    ]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [
      { "color": "#333333" }  // Water uses button highlighted color
    ]
  }
]
''';


// Fetch place suggestions
Future<List<dynamic>> _getPlaceSuggestions(String query) async {
  if (query.isEmpty) {
    return ["Current Location"];
  }

  final result = await places.findAutocompletePredictions(query);
  return ["Current Location", ...result.predictions];
}

// Fetch place details to get coordinates
Future<places_sdk.Place?> _getPlaceDetails(String placeId) async {
  final details = await places.fetchPlace(
    placeId,
    fields: [places_sdk.PlaceField.Location, places_sdk.PlaceField.Name, places_sdk.PlaceField.Address],
  );
  return details.place;
}

// Decode polyline using Google's polyline algorithm
List<maps.LatLng> _decodePolyline(String polyline) {
  List<maps.LatLng> points = [];
  int index = 0;
  int len = polyline.length;
  int lat = 0;
  int lng = 0;

  while (index < len) {
    int b, shift = 0, result = 0;
    do {
      b = polyline.codeUnitAt(index++) - 63;
      result |= (b & 0x1F) << shift;
      shift += 5;
    } while (b >= 0x20);
    int dlat = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
    lat += dlat;

    shift = 0;
    result = 0;
    do {
      b = polyline.codeUnitAt(index++) - 63;
      result |= (b & 0x1F) << shift;
      shift += 5;
    } while (b >= 0x20);
    int dlng = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
    lng += dlng;

    points.add(maps.LatLng(lat / 1E5, lng / 1E5));
  }

  return points;
}

// Fetch route from Google Directions API
Future<List<maps.LatLng>> _fetchRoute(maps.LatLng start, maps.LatLng end) async {
  final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json?origin=${start.latitude},${start.longitude}&destination=${end.latitude},${end.longitude}&key=$directionsApiKey'
  );

  final response = await http.get(url);
  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    if (data['routes'].isNotEmpty) {
      final polyline = data['routes'][0]['overview_polyline']['points'];
      return _decodePolyline(polyline);
    }
  }
  return [];
}

void main() {
  runApp(const App());
}

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late maps.GoogleMapController _mapController;

  // Colors and styles
  static const backgroundColor = Color(0xFF2A2A2A);
  static const buttonBackground = Color(0xFF232323);
  static const buttonHighlighted = Color(0xFF333333);
  static const accentColor = Color(0xFFE7E486);
  static const textActive = Color(0xFFF4F4F4);
  static const textInactive = Color(0xFFA4A4A4);

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
    if (_startLatLng == null || _destinationLatLng == null) return;

    final routePoints = await _fetchRoute(_startLatLng!, _destinationLatLng!);
    if (routePoints.isNotEmpty) {
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
      });

      // Adjust camera to show both markers:
      final swLat = min(_startLatLng!.latitude, _destinationLatLng!.latitude);
      final swLng = min(_startLatLng!.longitude, _destinationLatLng!.longitude);
      final neLat = max(_startLatLng!.latitude, _destinationLatLng!.latitude);
      final neLng = max(_startLatLng!.longitude, _destinationLatLng!.longitude);

      final bounds = maps.LatLngBounds(
        southwest: maps.LatLng(swLat, swLng),
        northeast: maps.LatLng(neLat, neLng),
      );

      // Animate camera:
      // Need to wait a frame for map to be fully rendered
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.animateCamera(
          maps.CameraUpdate.newLatLngBounds(bounds, 50),
        );
      });
    }
  }

  Future<void> _handleStartSelection(dynamic suggestion) async {
    if (suggestion == "Current Location") {
      // Get current location
      final position = await Geolocator.getCurrentPosition();
      _startLatLng = maps.LatLng(position.latitude, position.longitude);
      _startTextController?.text = "Your Current Location";
    } else {
      final prediction = suggestion as places_sdk.AutocompletePrediction;
      _startTextController?.text = prediction.fullText ?? prediction.primaryText ?? "";
      final place = await _getPlaceDetails(prediction.placeId);
      if (place != null && place.latLng != null) {
        _startLatLng = maps.LatLng(
          place.latLng!.lat,
          place.latLng!.lng,
        );
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
      _destinationTextController?.text = "Your Current Location";
    } else {
      final prediction = suggestion as places_sdk.AutocompletePrediction;
      _destinationTextController?.text = prediction.fullText ?? prediction.primaryText ?? "";
      final place = await _getPlaceDetails(prediction.placeId);
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
    return MaterialApp(
      home: Scaffold(
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
                  // Start Point Field
                  TypeAheadField(
                    hideOnEmpty: false,
                    showOnFocus: true,
                    suggestionsCallback: _getPlaceSuggestions,
                    itemBuilder: (context, suggestion) {
                      if (suggestion == "Current Location") {
                        return ListTile(
                          leading: const Icon(Icons.gps_fixed, color: accentColor),
                          title: const Text("Current Location", style: TextStyle(color: Colors.black)),
                        );
                      }
                      final prediction = suggestion as places_sdk.AutocompletePrediction;
                      return ListTile(
                        leading: const Icon(Icons.location_on, color: accentColor),
                        title: Text(
                          prediction.fullText ?? prediction.primaryText ?? "",
                          style: const TextStyle(color: Colors.black),
                        ),
                      );
                    },
                    onSelected: (suggestion) async {
                      await _handleStartSelection(suggestion);
                    },
                    builder: (context, textController, focusNode) {
                      _startTextController = textController;
                      return TextField(
                        controller: textController,
                        focusNode: focusNode,
                        style: const TextStyle(color: textActive),
                        decoration: const InputDecoration(
                          filled: true,
                          fillColor: buttonBackground,
                          hintText: 'Enter starting location',
                          hintStyle: TextStyle(color: textInactive),
                          prefixIcon: Icon(Icons.my_location, color: accentColor),
                          border: InputBorder.none,
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 16.0),

                  // Destination Field
                  TypeAheadField(
                    hideOnEmpty: false,
                    showOnFocus: true,
                    suggestionsCallback: _getPlaceSuggestions,
                    itemBuilder: (context, suggestion) {
                      if (suggestion == "Current Location") {
                        return ListTile(
                          leading: const Icon(Icons.gps_fixed, color: accentColor),
                          title: const Text("Current Location", style: TextStyle(color: Colors.black)),
                        );
                      }
                      final prediction = suggestion as places_sdk.AutocompletePrediction;
                      return ListTile(
                        leading: const Icon(Icons.location_on, color: accentColor),
                        title: Text(
                          prediction.fullText ?? prediction.primaryText ?? "",
                          style: const TextStyle(color: Colors.black),
                        ),
                      );
                    },
                    onSelected: (suggestion) async {
                      await _handleDestinationSelection(suggestion);
                    },
                    builder: (context, textController, focusNode) {
                      _destinationTextController = textController;
                      return TextField(
                        controller: textController,
                        focusNode: focusNode,
                        style: const TextStyle(color: textActive),
                        decoration: const InputDecoration(
                          filled: true,
                          fillColor: buttonBackground,
                          hintText: 'Enter destination',
                          hintStyle: TextStyle(color: textInactive),
                          prefixIcon: Icon(Icons.flag, color: accentColor),
                          border: InputBorder.none,
                        ),
                      );
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
                },
                polylines: _polylines,
                markers: _markers,
                style: _darkMapStyle,
              ),
            ),
          ],
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: () {
              // Start navigation logic
              // Here you have _startLatLng and _destinationLatLng and the route displayed.
              // You could integrate turn-by-turn instructions logic.
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonBackground,
              foregroundColor: textActive,
              minimumSize: const Size.fromHeight(50),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
            ).copyWith(
              overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
                if (states.contains(WidgetState.pressed)) {
                  return buttonHighlighted;
                }
                return null;
              }),
            ),
            child: const Text(
              'Start Navigation',
              style: TextStyle(fontSize: 18),
            ),
          ),
        ),
      ),
    );
  }
}
