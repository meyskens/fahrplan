import 'dart:async';

import 'package:fahrplan/models/r08/constants.dart';
import 'package:fahrplan/models/r08/ring.dart';
import 'package:fahrplan/models/r08/tap_event.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// High-level manager for the R08 smart ring.
///
/// Takes care of scanning, pairing, reconnecting from the saved device
/// identifier, enabling touch control after connection, and surfacing tap
/// events.
class RingManager {
  static final RingManager singleton = RingManager._internal();

  factory RingManager() => singleton;

  RingManager._internal();

  static const String _prefsKey = 'r08_ring_device_id';

  final _connectionStateController =
      StreamController<R08ConnectionState>.broadcast();
  final _tapController = StreamController<R08TapEvent>.broadcast();

  R08ConnectionState _connectionState = R08ConnectionState.disconnected;
  R08Ring? _ring;

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<bool>? _scanningStateSubscription;
  StreamSubscription<R08TapEvent>? _ringTapSubscription;
  Timer? _scanTimer;

  Stream<R08ConnectionState> get connectionStateStream =>
      _connectionStateController.stream;

  Stream<R08TapEvent> get tapEvents => _tapController.stream;

  R08ConnectionState get connectionState => _connectionState;

  bool get isConnected => _ring?.isConnected == true;

  set _state(R08ConnectionState state) {
    _connectionState = state;
    _connectionStateController.add(state);
  }

  Future<void> connectOrScan() async {
    if (_connectionState == R08ConnectionState.scanning ||
        _connectionState == R08ConnectionState.connecting) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString(_prefsKey);

    if (savedId != null && savedId.isNotEmpty) {
      try {
        _state = R08ConnectionState.connecting;
        final device = BluetoothDevice(remoteId: DeviceIdentifier(savedId));
        _ring = R08Ring(device: device);
        await _ring!.connect();
        await _finishConnection(savedId);
        return;
      } catch (e) {
        debugPrint('[RingManager] Reconnect from saved ID failed: $e');
        await _ring?.disconnect();
        _ring = null;
      }
    }

    await _startScan();
  }

  Future<void> disconnect() async {
    await _stopScan();
    await _ringTapSubscription?.cancel();
    _ringTapSubscription = null;
    await _ring?.disconnect();
    _ring = null;
    _state = R08ConnectionState.disconnected;
  }

  Future<void> _startScan() async {
    await FlutterBluePlus.stopScan();
    _state = R08ConnectionState.scanning;

    await FlutterBluePlus.startScan(
      withServices:
          R08Constants.scanServiceUuids.map((uuid) => Guid(uuid)).toList(),
      timeout: const Duration(seconds: 30),
      androidUsesFineLocation: true,
    );

    _scanTimer?.cancel();
    _scanTimer = Timer(const Duration(seconds: 30), () async {
      if (_connectionState == R08ConnectionState.scanning) {
        await _stopScan();
        _state = R08ConnectionState.disconnected;
      }
    });

    _scanSubscription?.cancel();
    _scanSubscription = FlutterBluePlus.scanResults.listen(
      _handleScanResults,
      onError: (dynamic e) => debugPrint('[RingManager] Scan error: $e'),
    );

    _scanningStateSubscription?.cancel();
    _scanningStateSubscription = FlutterBluePlus.isScanning.listen((scanning) {
      if (!scanning && _connectionState == R08ConnectionState.scanning) {
        _state = R08ConnectionState.disconnected;
      }
    });
  }

  Future<void> _stopScan() async {
    _scanTimer?.cancel();
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    await _scanningStateSubscription?.cancel();
    _scanningStateSubscription = null;
    await FlutterBluePlus.stopScan();
  }

  Future<void> _handleScanResults(List<ScanResult> results) async {
    if (results.isEmpty) return;

    // Prefer stronger signal; the ring should be close by.
    final candidate = results.reduce((a, b) => a.rssi > b.rssi ? a : b);

    await _stopScan();
    _state = R08ConnectionState.connecting;

    _ring = R08Ring(device: candidate.device);
    try {
      await _ring!.connect();
      await _finishConnection(candidate.device.remoteId.str);
    } catch (e) {
      debugPrint('[RingManager] Connect failed: $e');
      _state = R08ConnectionState.disconnected;
    }
  }

  Future<void> _finishConnection(String deviceId) async {
    await _ring!.enableTouchControl();

    await _ringTapSubscription?.cancel();
    _ringTapSubscription = _ring!.tapEvents.listen(_tapController.add);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, deviceId);

    _state = R08ConnectionState.connected;
  }

  void dispose() {
    disconnect();
    _connectionStateController.close();
    _tapController.close();
  }
}
