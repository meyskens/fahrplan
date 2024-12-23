import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import '../utils/constants.dart';
import '../models/glass.dart';
//import 'commands.dart';

typedef OnGlassFound = void Function(Glass);
typedef OnScanTimeout = void Function(String);
typedef OnScanError = void Function(String);

class BluetoothManager {
  Glass? leftGlass;
  Glass? rightGlass;
  Timer? _scanTimer;
  bool _isScanning = false;
  int _retryCount = 0;
  static const int maxRetries = 3;

  Future<void> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      //Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    statuses.forEach((permission, status) {
      if (status.isDenied) {
        print('Permission denied: $permission');
      } else if (status.isPermanentlyDenied) {
        print('Permission permanently denied: $permission');
      }
    });

    if (statuses.values.any((status) => status.isDenied)) {
      throw Exception('All permissions are required to use Bluetooth. Please enable them in the app settings.');
    }

    if (statuses.values.any((status) => status.isPermanentlyDenied)) {
      await openAppSettings();
      throw Exception('All permissions are required to use Bluetooth. Please enable them in the app settings.');
    }
  }

  Future<void> startScanAndConnect({
    required OnGlassFound onGlassFound,
    required OnScanTimeout onScanTimeout,
    required OnScanError onScanError,
  }) async {
    try {
      await _requestPermissions();

      if (!await FlutterBluePlus.isAvailable) {
        onScanError('Bluetooth is not available');
        return;
      }

      if (!await FlutterBluePlus.isOn) {
        onScanError('Bluetooth is turned off');
        return;
      }

      // Reset state
      _isScanning = true;
      _retryCount = 0;
      leftGlass = null;
      rightGlass = null;

      await _startScan(onGlassFound, onScanTimeout, onScanError);
    } catch (e) {
      print('Error in startScanAndConnect: $e');
      onScanError(e.toString());
    }
  }

  Future<void> _startScan(OnGlassFound onGlassFound,
      OnScanTimeout onScanTimeout, OnScanError onScanError) async {
    await FlutterBluePlus.stopScan();
    print('Starting new scan attempt ${_retryCount + 1}/$maxRetries');

    // Set scan timeout
    _scanTimer?.cancel();
    _scanTimer = Timer(const Duration(seconds: 30), () {
      if (_isScanning) {
        _handleScanTimeout(onGlassFound, onScanTimeout, onScanError);
      }
    });

    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 30),
      androidUsesFineLocation: true,
    );

    // Listen for scan results
    FlutterBluePlus.scanResults.listen(
          (results) {
        for (ScanResult result in results) {
          String deviceName = result.device.name;
          String deviceId = result.device.id.id;
          print('Found device: $deviceName ($deviceId)');

          if (deviceName.isNotEmpty) {
            _handleDeviceFound(result, onGlassFound);
          }
        }
      },
      onError: (error) {
        print('Scan results error: $error');
        onScanError(error.toString());
      },
    );

    // Monitor scanning state
    FlutterBluePlus.isScanning.listen((isScanning) {
      print('Scanning state changed: $isScanning');
      if (!isScanning && _isScanning) {
        _handleScanComplete(onGlassFound, onScanTimeout, onScanError);
      }
    });
  }

  void _handleDeviceFound(ScanResult result, OnGlassFound onGlassFound) {
    String deviceName = result.device.name;

    if (deviceName.contains('_L_') && leftGlass == null) {
      print('Found left glass: $deviceName');
      Glass glass = Glass(
        name: deviceName,
        device: result.device,
        side: 'left',
        onLeftStatusChanged: (status) => print('Left glass status: $status'),
        onRightStatusChanged: (_) {},
      );
      leftGlass = glass;
      onGlassFound(glass);
    } else if (deviceName.contains('_R_') && rightGlass == null) {
      print('Found right glass: $deviceName');
      Glass glass = Glass(
        name: deviceName,
        device: result.device,
        side: 'right',
        onLeftStatusChanged: (_) {},
        onRightStatusChanged: (status) => print('Right glass status: $status'),
      );
      rightGlass = glass;
      onGlassFound(glass);
    }

    // Stop scanning if both glasses are found
    if (leftGlass != null && rightGlass != null) {
      _isScanning = false;
      stopScanning();
    }
  }

  void _handleScanTimeout(OnGlassFound onGlassFound,
      OnScanTimeout onScanTimeout, OnScanError onScanError) async {
    print('Scan timeout occurred');

    if (_retryCount < maxRetries && (leftGlass == null || rightGlass == null)) {
      _retryCount++;
      print('Retrying scan (Attempt $_retryCount/$maxRetries)');
      await _startScan(onGlassFound, onScanTimeout, onScanError);
    } else {
      _isScanning = false;
      stopScanning();
      onScanTimeout(leftGlass == null && rightGlass == null
          ? 'No glasses found'
          : 'Scan completed');
    }
  }

  void _handleScanComplete(OnGlassFound onGlassFound,
      OnScanTimeout onScanTimeout, OnScanError onScanError) {
    if (_isScanning && (leftGlass == null || rightGlass == null)) {
      _handleScanTimeout(onGlassFound, onScanTimeout, onScanError);
    }
  }

  Future<void> connectToDevice(BluetoothDevice device,
      {required String side}) async {
    try {
      print('Attempting to connect to $side glass: ${device.name}');
      await device.connect(timeout: const Duration(seconds: 15));
      print('Connected to $side glass: ${device.name}');

      List<BluetoothService> services = await device.discoverServices();
      print('Discovered ${services.length} services for $side glass');

      for (BluetoothService service in services) {
        if (service.uuid.toString().toUpperCase() ==
            BluetoothConstants.UART_SERVICE_UUID) {
          print('Found UART service for $side glass');
          for (BluetoothCharacteristic characteristic
          in service.characteristics) {
            if (characteristic.uuid.toString().toUpperCase() ==
                BluetoothConstants.UART_TX_CHAR_UUID) {
              print('Found TX characteristic for $side glass');
            } else if (characteristic.uuid.toString().toUpperCase() ==
                BluetoothConstants.UART_RX_CHAR_UUID) {
              print('Found RX characteristic for $side glass');
            }
          }
        }
      }
    } catch (e) {
      print('Error connecting to $side glass: $e');
      await device.disconnect();
      rethrow;
    }
  }

  void stopScanning() {
    _scanTimer?.cancel();
    FlutterBluePlus.stopScan().then((_) {
      print('Stopped scanning');
      _isScanning = false;
    }).catchError((error) {
      print('Error stopping scan: $error');
    });
  }
}