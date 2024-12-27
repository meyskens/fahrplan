import 'dart:typed_data';
import 'dart:convert';

class Utils {
  Utils._();

  static int getTimestampMs() {
    return DateTime.now().millisecondsSinceEpoch;
  }

  static Uint8List addPrefixToUint8List(List<int> prefix, Uint8List data) {
    var newData = Uint8List(data.length + prefix.length);
    for (var i = 0; i < prefix.length; i++) {
      newData[i] = prefix[i];
    }
    for (var i = prefix.length, j = 0;
        i < prefix.length + data.length;
        i++, j++) {
      newData[i] = data[j];
    }
    return newData;
  }

  /// Convert binary array to hexadecimal string
  static String bytesToHexStr(Uint8List data, [String join = '']) {
    List<String> hexList =
        data.map((byte) => byte.toRadixString(16).padLeft(2, '0')).toList();
    String hexResult = hexList.join(join);
    return hexResult;
  }

  /// Divide Uint8List into chunks of specified size
  static List<Uint8List> divideUint8List(Uint8List data, int chunkSize) {
    List<Uint8List> chunks = [];
    for (var i = 0; i < data.length; i += chunkSize) {
      int end = (i + chunkSize < data.length) ? i + chunkSize : data.length;
      chunks.add(Uint8List.sublistView(data, i, end));
    }
    return chunks;
  }
}

class Crc32 extends Converter<Uint8List, int> {
  static final List<int> _table = _createTable();
  int _crc = 0xFFFFFFFF;

  @override
  int convert(Uint8List input) {
    add(input);
    return _crc;
  }

  @override
  void add(Uint8List data) {
    for (var byte in data) {
      _crc = (_crc >> 8) ^ _table[(byte ^ _crc) & 0xFF];
    }
  }

  @override
  int close() {
    return _crc ^ 0xFFFFFFFF;
  }

  static List<int> _createTable() {
    const int polynomial = 0xEDB88320;
    List<int> table = List<int>.filled(256, 0);
    for (int i = 0; i < 256; i++) {
      int crc = i;
      for (int j = 0; j < 8; j++) {
        if ((crc & 1) != 0) {
          crc = (crc >> 1) ^ polynomial;
        } else {
          crc = crc >> 1;
        }
      }
      table[i] = crc;
    }
    return table;
  }
}
