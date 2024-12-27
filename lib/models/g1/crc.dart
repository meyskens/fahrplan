import 'package:fahrplan/models/g1/commands.dart';

class CrcPacket {
  final int command = Commands.CRC;
  final List<int> data;

  CrcPacket({
    required this.data,
  });

  List<int> build() {
    return [
      command,
      ...data,
    ];
  }
}
