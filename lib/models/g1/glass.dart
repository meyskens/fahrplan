import 'package:fahrplan/models/g1/commands.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import '../../services/reciever.dart';
import '../../utils/constants.dart';

enum GlassSide { left, right }

class Glass {
  final String name;
  final GlassSide side;

  final BluetoothDevice device;

  BluetoothCharacteristic? uartTx;
  BluetoothCharacteristic? uartRx;

  StreamSubscription<List<int>>? notificationSubscription;
  Timer? heartbeatTimer;
  int heartbeatSeq = 0;

  get isConnected => device.isConnected;

  StreamController<Uint8List> replies = StreamController<Uint8List>();

  Glass({
    required this.name,
    required this.device,
    required this.side,
  });

  Future<void> connect() async {
    try {
      await device.connect();
      await discoverServices();
      device.requestMtu(251);
      startHeartbeat();
    } catch (e) {
      debugPrint('[$side Glass] Connection error: $e');
    }
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
    String hexData =
        data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    debugPrint('[$side Glass] Received data: $hexData');
    // Call the receive handler function

    replies.add(Uint8List.fromList(data));

    await receiveHandler(side, data);
  }

  Future<void> sendData(List<int> data) async {
    if (uartTx != null) {
      try {
        await uartTx!.write(data, withoutResponse: false);
        //debugPrint(
        //    'Sent data to $side glass: ${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
      } catch (e) {
        debugPrint('Error sending data to $side glass: $e');
      }
    } else {
      debugPrint('UART TX not available for $side glass.');
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

  void startHeartbeat() {
    const heartbeatInterval = Duration(seconds: 5);
    heartbeatTimer = Timer.periodic(heartbeatInterval, (timer) async {
      if (device.isConnected) {
        List<int> heartbeatData = _constructHeartbeat(heartbeatSeq++);
        await sendData(heartbeatData);
      }
    });
  }

  Future<void> disconnect() async {
    await device.disconnect();
    await notificationSubscription?.cancel();
    heartbeatTimer?.cancel();
    debugPrint('Disconnected from $side glass.');
  }
}
