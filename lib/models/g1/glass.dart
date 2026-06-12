import 'dart:io';

import 'package:fahrplan/models/g1/commands.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import '../../services/bluetooth_reciever.dart';
import '../../utils/constants.dart';

enum GlassSide { left, right }

class Glass {
  final String name;
  final GlassSide side;

  final BluetoothDevice device;

  BluetoothCharacteristic? uartTx;
  BluetoothCharacteristic? uartRx;

  StreamSubscription<List<int>>? notificationSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  Timer? heartbeatTimer;
  int heartbeatSeq = 0;

  // Reactive heartbeat tracking - for iOS background compatibility
  DateTime _lastActivityTime = DateTime.now();
  static const Duration _heartbeatInterval = Duration(seconds: 28);
  static const Duration _iosHeartbeatInterval = Duration(seconds: 25);

  // ACK tracking
  final Map<int, Completer<void>> _ackCompleters = {};

  get isConnected => device.isConnected;

  BluetoothReciever reciever = BluetoothReciever.singleton;

  Glass({
    required this.name,
    required this.device,
    required this.side,
  });

  Future<void> connect() async {
    try {
      // Use autoConnect for iOS - allows reconnection even when app is backgrounded
      // autoConnect is incompatible with specifying MTU in the same call
      await device.connect(
        autoConnect: Platform.isIOS,
        mtu: null, // Request MTU separately after connection
      );

      // Wait for connection to be established
      await device.connectionState
          .where((s) => s == BluetoothConnectionState.connected)
          .first;

      await discoverServices();

      // Request MTU after connection (required for G1)
      await device.requestMtu(251);

      if (Platform.isAndroid) {
        device.requestConnectionPriority(
            connectionPriorityRequest: ConnectionPriority.high);
      }

      // Start reactive heartbeat - works in background on iOS by piggybacking on incoming packets
      startReactiveHeartbeat();

      // Keep a watchdog that detects stale connections and reconnects.
      startConnectionWatchdog();

      // Set up connection state listener for auto-reconnect
      _setupConnectionListener();
    } catch (e) {
      debugPrint('[$side Glass] Connection error: $e');
    }
  }

  void _setupConnectionListener() {
    _connectionSubscription?.cancel();
    _connectionSubscription = device.connectionState.listen((state) {
      debugPrint('[$side Glass] Connection state: $state');
      if (state == BluetoothConnectionState.disconnected) {
        debugPrint('[$side Glass] Disconnected, attempting reconnect');
        _reconnectWithBackoff();
      }
    });
  }

  Future<void> discoverServices() async {
    List<BluetoothService> services = await device.discoverServices();
    for (BluetoothService service in services) {
      if (service.uuid.toString().toUpperCase() ==
          BluetoothConstants.UART_SERVICE_UUID) {
        for (BluetoothCharacteristic c in service.characteristics) {
          if (c.uuid.toString().toUpperCase() ==
              BluetoothConstants.UART_TX_CHAR_UUID) {
            if (c.properties.write) {
              uartTx = c;
              debugPrint('[$side Glass] UART TX Characteristic is writable.');
            } else {
              debugPrint(
                  '[$side Glass] UART TX Characteristic is not writable.');
            }
          } else if (c.uuid.toString().toUpperCase() ==
              BluetoothConstants.UART_RX_CHAR_UUID) {
            uartRx = c;
          }
        }
      }
    }
    if (uartRx != null) {
      await uartRx!.setNotifyValue(true);
      notificationSubscription = uartRx!.value.listen((data) {
        handleNotification(data);
      });
      debugPrint('[$side Glass] UART RX set to notify.');
    } else {
      debugPrint('[$side Glass] UART RX Characteristic not found.');
    }

    if (uartTx != null) {
      debugPrint('[$side Glass] UART TX Characteristic found.');
    } else {
      debugPrint('[$side Glass] UART TX Characteristic not found.');
    }
  }

  void handleNotification(List<int> data) async {
    // Update activity time for reactive heartbeat - critical for iOS background
    _lastActivityTime = DateTime.now();

    // Check if we need to send a heartbeat based on elapsed time
    _checkAndSendReactiveHeartbeat();

    //String hexData =
    //    data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    //debugPrint('[$side Glass] Received data: $hexData');
    // Call the receive handler function

    //replies.add(Uint8List.fromList(data));

    // Check if this is an ACK for a pending command
    if (data.isNotEmpty) {
      int commandByte = data[0];
      if (_ackCompleters.containsKey(commandByte)) {
        _ackCompleters[commandByte]?.complete();
        _ackCompleters.remove(commandByte);
      }
    }

    await reciever.receiveHandler(side, data);
  }

  /// Reactive heartbeat: sends heartbeat only when needed based on activity
  /// This is critical for iOS background operation where timers don't fire
  void _checkAndSendReactiveHeartbeat() {
    final elapsed = DateTime.now().difference(_lastActivityTime);
    final interval =
        Platform.isIOS ? _iosHeartbeatInterval : _heartbeatInterval;

    if (elapsed >= interval) {
      // Time to send a heartbeat
      _sendHeartbeatPacket();
    }
  }

  void _sendHeartbeatPacket() {
    if (device.isConnected) {
      List<int> heartbeatData = _constructHeartbeat(heartbeatSeq++);
      sendData(heartbeatData);
      _lastActivityTime = DateTime.now();
    }
  }

  Future<void> sendData(List<int> data) async {
    if (uartTx != null) {
      try {
        await uartTx!.write(data, withoutResponse: false);
        // Update activity time when sending data - for reactive heartbeat
        _lastActivityTime = DateTime.now();
        //debugPrint(
        //    'Sent data to $side glass: ${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
      } catch (e) {
        debugPrint('Error sending data to $side glass: $e');
      }
    } else {
      debugPrint('UART TX not available for $side glass.');
    }
  }

  Future<void> sendDataWithAck(List<int> data,
      {Duration timeout = const Duration(seconds: 2)}) async {
    if (data.isEmpty) {
      debugPrint('Cannot send empty data');
      return;
    }

    if (uartTx == null) {
      debugPrint('UART TX not available for $side glass.');
      return;
    }

    int commandByte = data[0];

    // Create a completer for this command's ACK
    final completer = Completer<void>();
    _ackCompleters[commandByte] = completer;

    try {
      // Send the data
      await uartTx!.write(data, withoutResponse: false);

      // Wait for ACK with timeout
      await completer.future.timeout(
        timeout,
        onTimeout: () {
          debugPrint(
              '[$side Glass] ACK timeout for command 0x${commandByte.toRadixString(16)}');
          _ackCompleters.remove(commandByte);
        },
      );
    } catch (e) {
      debugPrint('Error sending data to $side glass: $e');
      _ackCompleters.remove(commandByte);
      rethrow;
    }
  }

  List<int> _constructHeartbeat(int seq) {
    int length = 6;
    return [
      Commands.HEARTBEAT,
      length & 0xFF,
      (length >> 8) & 0xFF,
      seq % 0xFF,
      0x04,
      seq % 0xFF,
    ];
  }

  /// Best-effort periodic heartbeat. Android's foreground service keeps Dart
  /// running so the timer fires reliably. iOS timers are suspended in the
  /// background, so iOS also relies on reactive heartbeats and the
  /// BGProcessingTask scheduled from AppDelegate.
  void startReactiveHeartbeat() {
    // Cancel any existing timer
    heartbeatTimer?.cancel();

    if (Platform.isAndroid) {
      const heartbeatInterval = Duration(seconds: 5);
      heartbeatTimer = Timer.periodic(heartbeatInterval, (timer) async {
        if (device.isConnected) {
          _sendHeartbeatPacket();
        }
      });
    } else if (Platform.isIOS) {
      // iOS: keep a timer for foreground / short background windows.
      const heartbeatInterval = Duration(seconds: 25);
      heartbeatTimer = Timer.periodic(heartbeatInterval, (timer) async {
        if (device.isConnected) {
          _sendHeartbeatPacket();
        }
      });
    }
  }

  /// Sends a heartbeat if connected, otherwise attempts to reconnect.
  /// Called from the iOS background task and the watchdog.
  Future<void> heartbeatOrReconnect() async {
    if (device.isConnected) {
      _sendHeartbeatPacket();
    } else {
      await _reconnectWithBackoff();
    }
  }

  static const Duration _connectionWatchdogTimeout = Duration(seconds: 35);
  Timer? _watchdogTimer;

  void startConnectionWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _watchdogCheck();
    });
  }

  void _watchdogCheck() {
    if (!device.isConnected) return;
    final elapsed = DateTime.now().difference(_lastActivityTime);
    if (elapsed > _connectionWatchdogTimeout) {
      debugPrint('[$side Glass] Connection watchdog timeout, reconnecting');
      _reconnectWithBackoff();
    }
  }

  Future<void> _reconnectWithBackoff() async {
    for (final delay in [
      const Duration(seconds: 1),
      const Duration(seconds: 3),
      const Duration(seconds: 7),
      const Duration(seconds: 15),
    ]) {
      await Future.delayed(delay);
      if (device.isConnected) return;
      try {
        await connect();
        if (device.isConnected) return;
      } catch (e) {
        debugPrint('[$side Glass] Reconnect attempt failed: $e');
      }
    }
  }

  Future<void> disconnect() async {
    await device.disconnect();
    await notificationSubscription?.cancel();
    await _connectionSubscription?.cancel();
    heartbeatTimer?.cancel();
    _watchdogTimer?.cancel();
    debugPrint('Disconnected from $side glass.');
  }
}
