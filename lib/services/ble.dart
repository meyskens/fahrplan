import 'dart:typed_data';

class BleReceive {
  String lr = "";
  Uint8List data = Uint8List(0);
  String type = "";
  bool isTimeout = false;
 
  int getCmd() {
    return data[0].toInt();
  }

  BleReceive();
  static BleReceive fromMap(Map map) {
    var ret = BleReceive();
    ret.lr = map["lr"];
    ret.data = map["data"];
    ret.type = map["type"];
    return ret;
  }

  String hexStringData() {
    return data.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ');
  }
}

enum BleEvent {
  exitFunc,
  nextPageForEvenAI,
  upHeader,
  downHeader,
  glassesConnectSuccess, // 17、Bluetooth binding successful
  evenaiStart, // 23 Notify the phone to start Even AI
  evenaiRecordOver, // 24 Even AI recording ends
}