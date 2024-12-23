import '../services/commands.dart';
import 'dart:convert';

List<int> constructHeartbeat(int seq) {
  int length = 6;
  return [
    Command.HEARTBEAT.value,
    length & 0xFF,
    (length >> 8) & 0xFF,
    seq % 0xFF,
    0x04,
    seq % 0xFF,
  ];
}

List<int> buildSendResultPacket(String text) {
  SendResultPacket sendResult = SendResultPacket(
    command: Command.SEND_RESULT,
    data: utf8.encode(text),
  );
  return sendResult.build();
}
