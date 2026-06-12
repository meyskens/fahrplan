import 'dart:async';
import 'dart:io';

import 'package:fahrplan/models/r08/constants.dart';
import 'package:fahrplan/models/r08/tap_event.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Connection state of the R08 ring.
enum R08ConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
}

/// Encapsulates a single R08 smart ring BLE connection.
///
/// The protocol is documented in the R08 iOS sample app:
/// https://github.com/FilipposPirpilidis/r08-ios-sample
class R08Ring {
  final BluetoothDevice device;

  BluetoothCharacteristic? _writeCharacteristic;
  BluetoothCharacteristic? _notifyCharacteristic;

  StreamSubscription<List<int>>? _notifySubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;

  final _tapController = StreamController<R08TapEvent>.broadcast();

  /// Debounce state for multi-tap detection.
  DateTime? _lastTapTime;
  int _tapCount = 0;
  static const Duration _tapWindow = Duration(milliseconds: 600);
  Timer? _tapFinalizeTimer;

  R08Ring({required this.device});

  Stream<R08TapEvent> get tapEvents => _tapController.stream;

  bool get isConnected => device.isConnected;

  Future<void> connect() async {
    if (device.isConnected) {
      await discoverServices();
      return;
    }

    await device.connect(
      autoConnect: Platform.isIOS,
      mtu: null,
    );

    await device.connectionState
        .where((s) => s == BluetoothConnectionState.connected)
        .first;

    await discoverServices();

    _connectionSubscription?.cancel();
    _connectionSubscription = device.connectionState.listen((state) {
      debugPrint('[R08 Ring] Connection state: $state');
      if (state == BluetoothConnectionState.disconnected) {
        _cleanupCharacteristics();
      }
    });
  }

  Future<void> discoverServices() async {
    final services = await device.discoverServices();

    for (final service in services) {
      if (_matchesUuid(service.uuid, R08Constants.tapServiceUuid)) {
        for (final characteristic in service.characteristics) {
          if (_matchesUuid(
              characteristic.uuid, R08Constants.tapNotifyCharacteristicUuid)) {
            _notifyCharacteristic = characteristic;
          } else if (_writeCharacteristic == null &&
              R08Constants.preferredWriteCharacteristicUuids.any(
                (uuid) => _matchesUuid(characteristic.uuid, uuid),
              )) {
            _writeCharacteristic = characteristic;
          }
        }
      }
    }

    if (_notifyCharacteristic != null) {
      await _notifyCharacteristic!.setNotifyValue(true);
      _notifySubscription = _notifyCharacteristic!.lastValueStream.listen(
        _handleNotification,
        onError: (dynamic e) => debugPrint('[R08 Ring] Notify error: $e'),
      );
      debugPrint('[R08 Ring] Tap notifications enabled');
    } else {
      debugPrint('[R08 Ring] Tap notify characteristic not found');
    }

    if (_writeCharacteristic == null) {
      debugPrint('[R08 Ring] Write characteristic not found');
    }
  }

  void _cleanupCharacteristics() {
    _notifySubscription?.cancel();
    _notifySubscription = null;
    _writeCharacteristic = null;
    _notifyCharacteristic = null;
  }

  Future<void> enableTouchControl() async {
    await _writeCommand(R08Constants.touchControlOnCmd1);
    await _writeCommand(R08Constants.touchControlOnCmd2);
    debugPrint('[R08 Ring] Touch control enabled');
  }

  Future<void> disableTouchControl() async {
    await _writeCommand(R08Constants.touchControlOffCmd1);
    await Future.delayed(const Duration(milliseconds: 150));
    await _writeCommand(R08Constants.touchControlOffCmd2);
    await Future.delayed(const Duration(milliseconds: 150));
    await _writeCommand(R08Constants.touchControlOffCmd3);
    await Future.delayed(const Duration(milliseconds: 150));
    await _writeCommand(R08Constants.touchControlOffCmd4);
    debugPrint('[R08 Ring] Touch control disabled');
  }

  Future<void> _writeCommand(List<int> command) async {
    if (_writeCharacteristic == null) {
      debugPrint('[R08 Ring] Cannot write command: no write characteristic');
      return;
    }
    try {
      await _writeCharacteristic!.write(
        command,
        withoutResponse: false,
      );
    } catch (e) {
      debugPrint('[R08 Ring] Write error: $e');
    }
  }

  void _handleNotification(List<int> data) {
    if (!_isTapPacket(data)) return;

    final now = DateTime.now();
    if (_lastTapTime != null && now.difference(_lastTapTime!) <= _tapWindow) {
      _tapCount++;
    } else {
      _tapCount = 1;
    }
    _lastTapTime = now;

    _tapFinalizeTimer?.cancel();
    _tapFinalizeTimer = Timer(_tapWindow, () {
      final event = _tapEventFromCount(_tapCount);
      _tapController.add(event);
      _tapCount = 0;
      _lastTapTime = null;
    });
  }

  bool _isTapPacket(List<int> data) {
    return data.length >= 2 &&
        data[0] == R08Constants.tapPacketHeader0 &&
        data[1] == R08Constants.tapPacketHeader1;
  }

  R08TapEvent _tapEventFromCount(int count) {
    switch (count) {
      case 1:
        return R08TapEvent.single;
      case 2:
        return R08TapEvent.double;
      case 3:
        return R08TapEvent.triple;
      default:
        return R08TapEvent.quad;
    }
  }

  Future<void> disconnect() async {
    _tapFinalizeTimer?.cancel();
    await _notifySubscription?.cancel();
    await _connectionSubscription?.cancel();
    await device.disconnect();
    _cleanupCharacteristics();
    debugPrint('[R08 Ring] Disconnected');
  }

  void dispose() {
    _tapFinalizeTimer?.cancel();
    _notifySubscription?.cancel();
    _connectionSubscription?.cancel();
    _tapController.close();
  }

  static bool _matchesUuid(Guid guid, String uuid) {
    return guid.str.toUpperCase() == uuid.toUpperCase();
  }
}
