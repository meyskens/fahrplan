import 'package:flutter/services.dart';

class GlassesConnector {
  static const MethodChannel _channel = MethodChannel('method.bluetooth');

  Future<void> connectToGlasses(String deviceName) async {
    try {
      await _channel.invokeMethod('connectToGlasses', {'deviceName': deviceName});
      print("Connected to glasses!");
    } catch (e) {
      print("Error connecting to device: $e");
    }
  }
}
