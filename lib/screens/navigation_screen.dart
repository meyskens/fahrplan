import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as maps;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:navigate/models/glass.dart';
import 'package:navigate/services/commands.dart';
import '../utils/route_step.dart';
import '../services/directions_service.dart';
import '../utils/map_style.dart';
import '../utils/bitmap.dart'; // For generateNavigationBMP
import '../services/bluetooth_manager.dart'; // Your BLE service with scanning and connecting

class NavigationPage extends StatefulWidget {

  final List<RouteStep> steps;


  NavigationPage({
    super.key,
    required this.steps,
  });

  @override
  State<NavigationPage> createState() => _NavigationPageState();
}

class _NavigationPageState extends State<NavigationPage> {
  late maps.GoogleMapController _mapController;
  late StreamSubscription<Position> _locationSubscription;
  late StreamSubscription<CompassEvent> _headingSubscription;
  // Variables to hold connection status
  String leftStatus = 'Disconnected';
  String rightStatus = 'Disconnected';
  final BluetoothManager bluetoothManager = BluetoothManager();
  int _currentStepIndex = 0;
  maps.LatLng? _currentLocation;
  double _currentHeading = 0.0;
  List<maps.LatLng> _routePoints = [];
  final bool _isRerouting = false;
  bool _glassesConnected = false;
  Timer? _timer;

  // Colors and styles
  static const backgroundColor = Color(0xFF2A2A2A);
  static const accentColor = Color(0xFFE7E486);
  static const textActive = Color(0xFFF4F4F4);
  static const textInactive = Color(0xFFA4A4A4);

  @override
  void initState() {
    super.initState();

    _scanAndConnect();
      _fetchFullRoute();
      _startLocationTracking();
      _startCompassTracking();
        _startSendingCurrentStepToGlasses();
  }

  void _startSendingCurrentStepToGlasses() {
    _timer = Timer.periodic(Duration(seconds: 10), (timer) {
      _sendCurrentStepToGlasses();
    });
  }

  void _scanAndConnect() async {
    try {
      setState(() {
        leftStatus = 'Scanning...';
        rightStatus = 'Scanning...';
      });

      await bluetoothManager.startScanAndConnect(
        onGlassFound: (Glass glass) async {
          print('Glass found: ${glass.name} (${glass.side})');
          await _connectToGlass(glass);
        },
        onScanTimeout: (message) {
          print('Scan timeout: $message');
          setState(() {
            if (bluetoothManager.leftGlass == null) {
              leftStatus = 'Not Found';
            }
            if (bluetoothManager.rightGlass == null) {
              rightStatus = 'Not Found';
            }
          });
        },
        onScanError: (error) {
          print('Scan error: $error');
          setState(() {
            leftStatus = 'Scan Error';
            rightStatus = 'Scan Error';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Scan error: $error')),
          );
        },
      );
    } catch (e) {
      print('Error in _scanAndConnect: $e');
      setState(() {
        leftStatus = 'Error';
        rightStatus = 'Error';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _connectToGlass(Glass glass) async {
    await glass.connect();
    setState(() {
      if (glass.side == 'left') {
        leftStatus = 'Connecting...';
      } else {
        rightStatus = 'Connecting...';
      }
    });

    // Monitor connection
    glass.device.connectionState.listen((BluetoothConnectionState state) {
      if (glass.side == 'left') {
        leftStatus = state.toString().split('.').last;
      } else {
        rightStatus = state.toString().split('.').last;
      }
      setState(() {}); // Update the UI
      print('[${glass.side} Glass] Connection state: $state');
      if (state == BluetoothConnectionState.disconnected) {
        _glassesConnected = false;
        print('[${glass.side} Glass] Disconnected, attempting to reconnect...');
        setState(() {
          if (glass.side == 'left') {
            leftStatus = 'Reconnecting...';
          } else {
            rightStatus = 'Reconnecting...';
          }
        });
        _reconnectGlass(glass);
      }else if (state == BluetoothConnectionState.connected){
        _glassesConnected = true;
      }
    });
  }

  Future<void> _reconnectGlass(Glass glass) async {
    try {
      await glass.connect();
      print('[${glass.side} Glass] Reconnected.');
      setState(() {
        if (glass.side == 'left') {
          leftStatus = 'Connected';
        } else {
          rightStatus = 'Connected';
        }
      });
    } catch (e) {
      print('[${glass.side} Glass] Reconnection failed: $e');
      setState(() {
        if (glass.side == 'left') {
          leftStatus = 'Disconnected';
        } else {
          rightStatus = 'Disconnected';
        }
      });
    }
  }

  void _sendBitmap(Uint8List bitmapData) async {

  if (bluetoothManager.leftGlass != null && bluetoothManager.rightGlass != null) {
    await sendBitmap(
      bitmapData,
      bluetoothManager
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Glasses are not connected')),
    );
  }
}

  Future<void> _sendCurrentStepToGlasses() async {
    if (!_glassesConnected) {
      print("Glasses are not connected. Cannot send step data.");
      return;
    }

    if (_currentStepIndex < widget.steps.length) {
      final currentStep = widget.steps[_currentStepIndex];

      // Distance parsing from step distance string (e.g., "200 m" or "1.2 km")
      double distanceValue = 0.0;
      final distanceStr = currentStep.distance.toLowerCase();
      if (distanceStr.contains("km")) {
        // Convert km to m
        final kmValue = double.parse(distanceStr.replaceAll('km', '').trim());
        distanceValue = kmValue * 1000;
      } else if (distanceStr.contains("m")) {
        distanceValue = double.parse(distanceStr.replaceAll('m', '').trim());
      }

      final bmpData = await generateNavigationBMP(currentStep.maneuver, distanceValue);

      // Instead of sending immediately, set the BMP data so it will be sent once every second
      _sendBitmap(bmpData);
    }
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

      // If close to the next step and not at the last step, move to the next step
      if (distanceToNextStep < 20 && _currentStepIndex < widget.steps.length - 1) {
        setState(() {
          _currentStepIndex++;
        });
        _sendCurrentStepToGlasses(); // Will set BMP data, updated once per second
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
    bluetoothManager.leftGlass?.disconnect();
    bluetoothManager.rightGlass?.disconnect();
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
