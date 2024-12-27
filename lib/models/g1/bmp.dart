import 'package:fahrplan/models/g1/commands.dart';

class BmpPacket {
  final int command = Commands.BMP;
  final int seq;
  final List<int> data;

  BmpPacket({
    this.seq = 0,
    required this.data,
  });

  List<int> build() {
    return [
      command,
      seq & 0xFF,
      ...data,
    ];
  }
}
