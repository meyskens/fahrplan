import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import '../services/commands.dart';
import '../services/reciever.dart';
import '../utils/constants.dart';

class Glass {
  final String name;
  final String side; // 'left' or 'right'
  final BluetoothDevice device;
  BluetoothCharacteristic? uartTx;
  BluetoothCharacteristic? uartRx;

  StreamSubscription<List<int>>? notificationSubscription;
  Timer? heartbeatTimer;
  int heartbeatSeq = 0;

  final Function(String) onLeftStatusChanged;
  final Function(String) onRightStatusChanged;

  Glass({
    required this.name,
    required this.device,
    required this.side,
    required this.onLeftStatusChanged,
    required this.onRightStatusChanged,
  });

  Future<void> connect() async {
    try {
      await device.connect();
      await discoverServices();
      startHeartbeat();
      // Update connection state after successful connection
      if (side == 'left') {
        onLeftStatusChanged('Connected');
      } else {
        onRightStatusChanged('Connected');
      }
    } catch (e) {
      print('[$side Glass] Connection error: $e');
      if (side == 'left') {
        onLeftStatusChanged('Connection Failed');
      } else {
        onRightStatusChanged('Connection Failed');
      }
    }
  }

  Future<void> discoverServices() async {
    List<BluetoothService> services = await device.discoverServices();
    for (BluetoothService service in services) {
      if (service.uuid.toString().toUpperCase() == BluetoothConstants.UART_SERVICE_UUID) {
        for (BluetoothCharacteristic c in service.characteristics) {
          if (c.uuid.toString().toUpperCase() == BluetoothConstants.UART_TX_CHAR_UUID) {
            if (c.properties.write) {
              uartTx = c;
              print('[$side Glass] UART TX Characteristic is writable.');
            } else {
              print('[$side Glass] UART TX Characteristic is not writable.');
            }
          } else if (c.uuid.toString().toUpperCase() == BluetoothConstants.UART_RX_CHAR_UUID) {
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
      print('[$side Glass] UART RX set to notify.');
    } else {
      print('[$side Glass] UART RX Characteristic not found.');
    }

    if (uartTx != null) {
      print('[$side Glass] UART TX Characteristic found.');
    } else {
      print('[$side Glass] UART TX Characteristic not found.');
    }
  }

  void handleNotification(List<int> data) async {
    String hexData = data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    print('[$side Glass] Received data: $hexData');
    // Call the receive handler function
    await receiveHandler(side, data);
  }

  Future<void> sendData(List<int> data) async {
    if (uartTx != null) {
      try {
        await uartTx!.write(data, withoutResponse: false);
        print('Sent data to $side glass: ${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
      } catch (e) {
        print('Error sending data to $side glass: $e');
      }
    } else {
      print('UART TX not available for $side glass.');
    }
  }

  void startHeartbeat() {
    const heartbeatInterval = Duration(seconds: 5);
    heartbeatTimer = Timer.periodic(heartbeatInterval, (timer) async {
      if (device.connectionState == BluetoothConnectionState.connected) {
        List<int> heartbeatData = constructHeartbeat(heartbeatSeq++);
        await sendData(heartbeatData);
      }
    });
  }

  Future<void> disconnect() async {
    await device.disconnect();
    await notificationSubscription?.cancel();
    heartbeatTimer?.cancel();
    print('Disconnected from $side glass.');
  }
}
