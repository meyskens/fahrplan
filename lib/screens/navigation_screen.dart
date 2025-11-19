import 'package:fahrplan/services/bluetooth_manager.dart';
import 'package:fahrplan/services/mapbox_service.dart';
import 'package:fahrplan/utils/bitmap.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:convert';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final TextEditingController _searchController = TextEditingController();
  final BluetoothManager bluetoothManager = BluetoothManager();
  final MapboxService _mapboxService = MapboxService();

  MapboxMap? _mapboxMap;
  PolylineAnnotationManager? _routeLineManager;
  PointAnnotationManager? _markerManager;
  PointAnnotationManager? _currentLocationMarker;
  Snapshotter? _snapshotter;
  Position? _currentPosition;
  Position? _destinationPosition;
  bool _isNavigating = false;
  MapboxRoute? _currentRoute;
  int _currentStepIndex = 0;
  StreamSubscription? _navigationTimer;
  StreamSubscription? _locationUpdateTimer;
  bool _isSearching = false;
  String? _mapboxAccessToken;

  @override
  void initState() {
    super.initState();
    _loadMapboxToken();
  }

  Future<void> _loadMapboxToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('mapbox_api_key');

    if (token != null && token.isNotEmpty) {
      // Set the Mapbox access token globally
      try {
        MapboxOptions.setAccessToken(token);
      } catch (e) {
        debugPrint('Error setting Mapbox token: $e');
      }
    }

    setState(() {
      _mapboxAccessToken = token;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _navigationTimer?.cancel();
    _locationUpdateTimer?.cancel();
    _snapshotter?.dispose();
    if (_isNavigating) {
      bluetoothManager.endNavigation();
    }
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    if (_mapboxMap == null) return;

    try {
      // Check and request location permissions
      bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled');
        return;
      }

      geo.LocationPermission permission =
          await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
        if (permission == geo.LocationPermission.denied) {
          debugPrint('Location permissions are denied');
          return;
        }
      }

      if (permission == geo.LocationPermission.deniedForever) {
        debugPrint('Location permissions are permanently denied');
        return;
      }

      // Get the actual GPS location
      final geoPosition = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
        ),
      );

      setState(() {
        _currentPosition =
            Position(geoPosition.longitude, geoPosition.latitude);
      });

      // Center the map on the current location with higher zoom
      await _mapboxMap!.flyTo(
        CameraOptions(
          center: Point(
              coordinates:
                  Position(geoPosition.longitude, geoPosition.latitude)),
          zoom: 15.0,
        ),
        MapAnimationOptions(duration: 1000),
      );
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  Future<void> _startLocationTracking() async {
    if (_mapboxMap == null) return;

    try {
      // Enable location component to show user's current position
      await _mapboxMap!.location.updateSettings(LocationComponentSettings(
        enabled: true,
        pulsingEnabled: true,
        pulsingColor: Colors.blue.value,
        showAccuracyRing: true,
      ));

      // Initialize current location marker manager
      _currentLocationMarker ??=
          await _mapboxMap!.annotations.createPointAnnotationManager();

      // Poll for location updates during navigation
      _locationUpdateTimer =
          Stream.periodic(const Duration(seconds: 2)).listen((_) async {
        if (!_isNavigating) return;

        try {
          // Get the actual GPS location
          final geoPosition = await geo.Geolocator.getCurrentPosition(
            locationSettings: const geo.LocationSettings(
              accuracy: geo.LocationAccuracy.high,
            ),
          );

          final newPosition =
              Position(geoPosition.longitude, geoPosition.latitude);

          if (newPosition.lng != _currentPosition?.lng ||
              newPosition.lat != _currentPosition?.lat) {
            setState(() {
              _currentPosition = newPosition;
            });
          }
        } catch (e) {
          debugPrint('Error tracking location: $e');
        }
      });
    } catch (e) {
      debugPrint('Error enabling location: $e');
    }
  }

  Future<void> _searchAndNavigate() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a destination')),
      );
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      // Search for the destination using Mapbox Geocoding API
      final places = await _mapboxService.searchPlaces(
        query,
        latitude: _currentPosition?.lat.toDouble(),
        longitude: _currentPosition?.lng.toDouble(),
      );

      if (places.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No results found')),
          );
        }
        return;
      }

      // Use the first result
      final destination = places.first;
      setState(() {
        _destinationPosition =
            Position(destination.longitude, destination.latitude);
      });

      // Update map to show destination
      if (_mapboxMap != null) {
        _mapboxMap!.flyTo(
          CameraOptions(
            center: Point(
              coordinates:
                  Position(destination.longitude, destination.latitude),
            ),
            zoom: 12.0,
          ),
          MapAnimationOptions(duration: 2000),
        );
      }

      // Get directions and start navigation
      await _getDirectionsAndNavigate();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  Future<void> _getDirectionsAndNavigate() async {
    if (_currentPosition == null || _destinationPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Missing current or destination position')),
      );
      return;
    }

    if (!bluetoothManager.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Glasses are not connected')),
      );
      return;
    }

    try {
      // Get real directions from Mapbox
      final route = await _mapboxService.getDirections(
        startLat: _currentPosition!.lat.toDouble(),
        startLng: _currentPosition!.lng.toDouble(),
        endLat: _destinationPosition!.lat.toDouble(),
        endLng: _destinationPosition!.lng.toDouble(),
        profile: 'driving',
      );

      setState(() {
        _currentRoute = route;
        _isNavigating = true;
        _currentStepIndex = 0;
      });

      // Draw the route on the map
      await _drawRouteOnMap(route);

      // Initialize navigation on glasses
      await bluetoothManager.startNavigation();
      await Future.delayed(const Duration(milliseconds: 8));

      // Send initial navigation images
      await _sendNavigationImages();

      // Start sending navigation updates
      _startNavigationUpdates();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting directions: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _drawRouteOnMap(MapboxRoute route) async {
    if (_mapboxMap == null) return;

    // Initialize annotation managers if not already done
    _routeLineManager ??=
        await _mapboxMap!.annotations.createPolylineAnnotationManager();
    _markerManager ??=
        await _mapboxMap!.annotations.createPointAnnotationManager();

    // Clear existing annotations
    await _routeLineManager!.deleteAll();
    await _markerManager!.deleteAll();

    // Create route line from geometry
    final lineCoordinates =
        route.geometry.map((coord) => Position(coord[0], coord[1])).toList();

    final routeLine = PolylineAnnotationOptions(
      geometry: LineString(coordinates: lineCoordinates),
      lineColor: Colors.blue.value,
      lineWidth: 5.0,
    );
    await _routeLineManager!.create(routeLine);

    // Add start marker
    if (_currentPosition != null) {
      final startMarker = PointAnnotationOptions(
        geometry: Point(
          coordinates: Position(_currentPosition!.lng, _currentPosition!.lat),
        ),
        iconSize: 1.5,
        iconColor: Colors.green.value,
      );
      await _markerManager!.create(startMarker);
    }

    // Add destination marker
    if (_destinationPosition != null) {
      final endMarker = PointAnnotationOptions(
        geometry: Point(
          coordinates:
              Position(_destinationPosition!.lng, _destinationPosition!.lat),
        ),
        iconSize: 1.5,
        iconColor: Colors.red.value,
      );
      await _markerManager!.create(endMarker);
    }

    // Fit camera to show entire route
    if (lineCoordinates.isNotEmpty) {
      // Calculate bounds
      double minLng = lineCoordinates[0].lng.toDouble();
      double maxLng = lineCoordinates[0].lng.toDouble();
      double minLat = lineCoordinates[0].lat.toDouble();
      double maxLat = lineCoordinates[0].lat.toDouble();

      for (var pos in lineCoordinates) {
        final lng = pos.lng.toDouble();
        final lat = pos.lat.toDouble();
        if (lng < minLng) minLng = lng;
        if (lng > maxLng) maxLng = lng;
        if (lat < minLat) minLat = lat;
        if (lat > maxLat) maxLat = lat;
      }

      final centerLng = (minLng + maxLng) / 2;
      final centerLat = (minLat + maxLat) / 2;

      // Add padding
      final padding = 0.01;
      final bounds = CoordinateBounds(
        southwest:
            Point(coordinates: Position(minLng - padding, minLat - padding)),
        northeast:
            Point(coordinates: Position(maxLng + padding, maxLat + padding)),
        infiniteBounds: true,
      );

      await _mapboxMap!.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(centerLng, centerLat)),
        ),
        MapAnimationOptions(duration: 1500),
      );

      // Set camera to bounds
      await _mapboxMap!.setBounds(CameraBoundsOptions(bounds: bounds));
    }
  }

  Future<void> _sendNavigationImages() async {
    await bluetoothManager.sendNavigationPoller();

    // Generate and send primary image (136x136) using Mapbox Snapshotter
    final primaryImage = await _generateMapSnapshot(136, 136);
    //final primaryOverlay = _generateEmptyMap(136, 136);
    await bluetoothManager.sendNavigationPrimaryImage(
      image: primaryImage,
      overlay: primaryImage,
    );
    await Future.delayed(const Duration(milliseconds: 8));

    // Generate and send secondary image (488x136)
    final secondaryImage = await _generateMapSnapshot(488, 136);
    await bluetoothManager.sendNavigationSecondaryImage(
      image: secondaryImage,
      overlay: secondaryImage,
    );

    await bluetoothManager.sendNavigationPoller();
  }

  Future<List<int>> _generateMapSnapshot(int width, int height) async {
    try {
      // Initialize snapshotter if not already done
      if (_snapshotter == null) {
        final options = MapSnapshotOptions(
          size: Size(width: width.toDouble(), height: height.toDouble()),
          pixelRatio: 1.0,
        );

        _snapshotter = await Snapshotter.create(options: options);

        // Set custom monochrome style optimized for 1-bit conversion
        await _snapshotter!.style
            .setStyleURI("mapbox://styles/maartjeme/cmi6l4nzc00d201sldrcb1mc9");
      } else {
        // Update size if snapshotter already exists
        await _snapshotter!.setSize(
          Size(width: width.toDouble(), height: height.toDouble()),
        );
      }

      // Set camera to current map view
      if (_mapboxMap != null) {
        final cameraState = await _mapboxMap!.getCameraState();
        await _snapshotter!.setCamera(CameraOptions(
          center: cameraState.center,
          zoom: cameraState.zoom,
          bearing: cameraState.bearing,
          pitch: cameraState.pitch,
        ));
      }

      // Add route line to snapshotter if we have a route
      if (_currentRoute != null) {
        await _addRouteToSnapshot();
      }

      // Generate the snapshot
      final snapshotData = await _snapshotter!.start();

      if (snapshotData == null) {
        debugPrint('Snapshot generation returned null, using fallback');
        return _generateEmptyMap(width, height);
      }

      // Debug: Show the snapshot in a modal
      if (mounted) {
        _showSnapshotDebugModal(snapshotData);
      }

      // Convert the image data to 1-bit monochrome
      return await _convertSnapshotTo1Bit(snapshotData, width, height);
    } catch (e) {
      debugPrint('Error generating map snapshot: $e');
      // Fallback to demo road map if snapshot fails
      return _generateEmptyMap(width, height);
    }
  }

  Future<void> _addRouteToSnapshot() async {
    if (_snapshotter == null || _currentRoute == null) return;

    try {
      // Add a GeoJSON source with the route line
      final lineCoordinates =
          _currentRoute!.geometry.map((coord) => [coord[0], coord[1]]).toList();

      final geoJsonSource = {
        "type": "FeatureCollection",
        "features": [
          {
            "type": "Feature",
            "geometry": {
              "type": "LineString",
              "coordinates": lineCoordinates,
            },
            "properties": {}
          }
        ]
      };

      // Add source to snapshotter style
      await _snapshotter!.style.addSource(
        GeoJsonSource(
          id: "route-source",
          data: jsonEncode(geoJsonSource),
        ),
      );

      // Add layer to display the route
      await _snapshotter!.style.addLayer(
        LineLayer(
          id: "route-layer",
          sourceId: "route-source",
          lineColor: Colors.blue.value,
          lineWidth: 5.0,
        ),
      );

      // Add start and end markers
      if (_currentPosition != null && _destinationPosition != null) {
        final markersSource = {
          "type": "FeatureCollection",
          "features": [
            {
              "type": "Feature",
              "geometry": {
                "type": "Point",
                "coordinates": [
                  _currentPosition!.lng.toDouble(),
                  _currentPosition!.lat.toDouble()
                ],
              },
              "properties": {"marker-type": "start"}
            },
            {
              "type": "Feature",
              "geometry": {
                "type": "Point",
                "coordinates": [
                  _destinationPosition!.lng.toDouble(),
                  _destinationPosition!.lat.toDouble()
                ],
              },
              "properties": {"marker-type": "end"}
            }
          ]
        };

        await _snapshotter!.style.addSource(
          GeoJsonSource(
            id: "markers-source",
            data: jsonEncode(markersSource),
          ),
        );

        // Add circle layers for markers
        await _snapshotter!.style.addLayer(
          CircleLayer(
            id: "start-marker",
            sourceId: "markers-source",
            circleRadius: 8.0,
            circleColor: Colors.green.value,
            filter: [
              "==",
              ["get", "marker-type"],
              "start"
            ],
          ),
        );

        await _snapshotter!.style.addLayer(
          CircleLayer(
            id: "end-marker",
            sourceId: "markers-source",
            circleRadius: 8.0,
            circleColor: Colors.red.value,
            filter: [
              "==",
              ["get", "marker-type"],
              "end"
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('Error adding route to snapshot: $e');
      // Try to remove any partially added layers/sources
      try {
        await _snapshotter!.style.removeStyleLayer("route-layer");
        await _snapshotter!.style.removeStyleSource("route-source");
        await _snapshotter!.style.removeStyleLayer("start-marker");
        await _snapshotter!.style.removeStyleLayer("end-marker");
        await _snapshotter!.style.removeStyleSource("markers-source");
      } catch (_) {
        // Ignore cleanup errors
      }
    }
  }

  Future<List<int>> _convertSnapshotTo1Bit(
      Uint8List imageData, int width, int height) async {
    // Use the bitmap utility to generate a 1-bit BMP from the snapshot
    final bmpBytes = await generateBMPFromImageData(
      imageData,
      width: width,
      height: height,
      backgroundColor: const ui.Color(0xFFFFFFFF),
      scaleToFit: false,
      debugFileName: 'navigation_snapshot.bmp',
    );

    // Extract the pixel data from the BMP file
    // BMP header is 62 bytes for 1-bit BMP
    const headerSize = 62;
    final bytesPerRow = width ~/ 8;
    final imageSize = bytesPerRow * height;

    if (bmpBytes.length < headerSize + imageSize) {
      throw Exception('Invalid BMP data size');
    }

    final bmpData = bmpBytes.sublist(headerSize, headerSize + imageSize);
    // final totalPixels = width * height;
    // final monochrome = List<bool>.filled(totalPixels, false);

    // // Convert BMP data to List<bool>
    // // BMP is stored bottom-up, so we need to flip it
    // for (int y = 0; y < height; y++) {
    //   final invertedY = (height - 1 - y);
    //   final rowStart = invertedY * bytesPerRow;

    //   for (int x = 0; x < width; x++) {
    //     final byteIndex = rowStart + (x ~/ 8);
    //     final bitOffset = 7 - (x % 8);
    //     final bit = (bmpData[byteIndex] >> bitOffset) & 1;
    //     monochrome[y * width + x] = bit == 0;
    //   }
    // }

    return bmpData;
  }

  List<int> _generateEmptyMap(int width, int height) {
    final totalPixels = width * height;
    final bits = List<bool>.filled(totalPixels, false);

    final bytes = <int>[];
    for (int i = 0; i < bits.length; i += 8) {
      int byte = 0;
      for (int j = 0; j < 8 && (i + j) < bits.length; j++) {
        if (bits[i + j]) {
          byte |= (1 << (7 - j));
        }
      }
      bytes.add(byte);
    }
    return bytes;
  }

  void _showSnapshotDebugModal(Uint8List imageData) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Snapshot Debug',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Image.memory(
                imageData,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 16),
              Text('Size: ${imageData.length} bytes'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<bool> _generateDemoOverlay(int width, int height, int step,
      {(int, int)? position}) {
    final totalPixels = width * height;
    final overlay = List<bool>.filled(totalPixels, false);

    // Draw route line
    final centerX = width ~/ 2;
    for (int y = 0; y < height; y++) {
      final offset = (step * 5 + y ~/ 10) % 20 - 10;
      final x = centerX + offset;
      if (x >= 0 && x < width) {
        overlay[y * width + x] = true;
        if (x + 1 < width) overlay[y * width + x + 1] = true;
        if (x - 1 >= 0) overlay[y * width + x - 1] = true;
      }
    }

    // Draw position marker if provided
    if (position != null) {
      final (px, py) = position;
      for (int dy = -3; dy <= 3; dy++) {
        for (int dx = -3; dx <= 3; dx++) {
          if ((dx.abs() <= 1 && dy.abs() <= 3) ||
              (dx.abs() <= 3 && dy.abs() <= 1)) {
            final x = px + dx;
            final y = py + dy;
            if (x >= 0 && x < width && y >= 0 && y < height) {
              overlay[y * width + x] = true;
            }
          }
        }
      }
    }

    return overlay;
  }

  void _startNavigationUpdates() {
    _navigationTimer =
        Stream.periodic(const Duration(seconds: 3)).listen((_) async {
      if (!_isNavigating ||
          _currentRoute == null ||
          _currentStepIndex >= _currentRoute!.steps.length) {
        _stopNavigation();
        return;
      }

      await bluetoothManager.sendNavigationPoller();

      final step = _currentRoute!.steps[_currentStepIndex];

      // Calculate remaining distance and duration
      double remainingDistance = 0;
      double remainingDuration = 0;
      for (int i = _currentStepIndex; i < _currentRoute!.steps.length; i++) {
        remainingDistance += _currentRoute!.steps[i].distance;
        remainingDuration += _currentRoute!.steps[i].duration;
      }

      final xPos = 244; // Center of secondary map
      final yPos = 68;

      // Format distances
      final distanceStr = step.distance >= 1000
          ? '${(step.distance / 1000).toStringAsFixed(1)}km'
          : '${step.distance.toStringAsFixed(0)}m';

      final totalDistanceStr = remainingDistance >= 1000
          ? '${(remainingDistance / 1000).toStringAsFixed(1)}km'
          : '${remainingDistance.toStringAsFixed(0)}m';

      // Format duration
      final totalDurationStr = remainingDuration >= 3600
          ? '${(remainingDuration / 3600).toStringAsFixed(0)}h ${((remainingDuration % 3600) / 60).toStringAsFixed(0)}m'
          : '${(remainingDuration / 60).toStringAsFixed(0)}m';

      await bluetoothManager.sendNavigationDirections(
        totalDuration: totalDurationStr,
        totalDistance: totalDistanceStr,
        direction: step.instruction,
        distance: distanceStr,
        speed: '50km/h', // Could be calculated from actual speed if available
        directionTurn: step.toDirectionTurn(),
        customX: [(xPos >> 8) & 0xFF, xPos & 0xFF],
        customY: yPos,
      );

      setState(() {
        _currentStepIndex++;
      });
    });
  }

  Future<void> _stopNavigation() async {
    _navigationTimer?.cancel();
    if (_isNavigating && bluetoothManager.isConnected) {
      await bluetoothManager.endNavigation();
    }

    // Clear route from map
    await _routeLineManager?.deleteAll();
    await _markerManager?.deleteAll();

    setState(() {
      _isNavigating = false;
      _currentStepIndex = 0;
      _currentRoute = null;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Navigation completed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Navigation'),
        actions: [
          if (_isNavigating)
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: _stopNavigation,
              tooltip: 'Stop Navigation',
            ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Where to?',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (_) => _searchAndNavigate(),
                    enabled: !_isNavigating,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: (_isNavigating || _isSearching)
                      ? null
                      : _searchAndNavigate,
                  child: _isSearching
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Go'),
                ),
              ],
            ),
          ),
          // Map view
          Expanded(
            child: _mapboxAccessToken == null || _mapboxAccessToken!.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.map, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text(
                            'Mapbox API Key Not Configured',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Please configure your Mapbox API key in Settings > Mapbox',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.settings),
                            label: const Text('Go to Settings'),
                          ),
                        ],
                      ),
                    ),
                  )
                : MapWidget(
                    key: const ValueKey("mapWidget"),
                    onMapCreated: (MapboxMap map) async {
                      _mapboxMap = map;
                      // Enable location tracking once map is created
                      await _startLocationTracking();
                      // Update to show current GPS position
                      await _getCurrentLocation();
                    },
                  ),
          ),
          // Navigation status
          if (_isNavigating && _currentRoute != null)
            Container(
              padding: const EdgeInsets.all(16.0),
              color: Colors.blue.shade100,
              child: Column(
                children: [
                  Text(
                    'Step ${_currentStepIndex + 1} of ${_currentRoute!.steps.length}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_currentStepIndex < _currentRoute!.steps.length)
                    Text(
                      _currentRoute!.steps[_currentStepIndex].instruction,
                      style: const TextStyle(fontSize: 14),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
