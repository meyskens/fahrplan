import 'package:flutter/services.dart';

class LC3 {
  static const MethodChannel _channel =
      MethodChannel('dev.maartje.fahrplan/channel');

  static Future<Uint8List> decodeLC3(Uint8List data) async {
    try {
      final Uint8List decodedData =
          await _channel.invokeMethod('decodeLC3', {'data': data});
      return decodedData;
    } on PlatformException catch (e) {
      throw 'Failed to decode LC3: ${e.message}';
    }
  }
}
