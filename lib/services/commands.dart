import 'dart:convert';
import 'dart:typed_data';
import 'package:navigate/utils/utils.dart';
//import 'package:even_glasses/models/notification.dart';

import '../services/bluetooth_manager.dart';

enum Command {
  START_AI(0xF5),
  OPEN_MIC(0x0E),
  MIC_RESPONSE(0x0E),
  RECEIVE_MIC_DATA(0xF1),
  INIT(0x4D),
  HEARTBEAT(0x25),
  SEND_RESULT(0x4E),
  QUICK_NOTE(0x21),
  DASHBOARD(0x22),
  NOTIFICATION(0x4B),
  BMP(0x15),
  CRC(0x16);

  final int value;
  const Command(this.value);
}

class CrcPacket {
  final Command command;
  final List<int> data;

  CrcPacket({
    required this.command,
    required this.data,
  });

  List<int> build() {
    return [
      command.value,
      ...data,
    ];
  }
}

class BmpPacket {
  final Command command;
  final int seq;
  final List<int> data;

  BmpPacket({
    required this.command,
    this.seq = 0,
    required this.data,
  });

  List<int> build() {
    return [
      command.value,
      seq & 0xFF,
      ...data,
    ];
  }
}

class SendResultPacket {
  final Command command;
  final int seq;
  final int totalPackages;
  final int currentPackage;
  final int screenStatus;
  final int newCharPos0;
  final int newCharPos1;
  final int pageNumber;
  final int maxPages;
  final List<int> data;

  SendResultPacket({
    required this.command,
    this.seq = 0,
    this.totalPackages = 1,
    this.currentPackage = 0,
    this.screenStatus = 0x31, // Example value
    this.newCharPos0 = 0,
    this.newCharPos1 = 0,
    this.pageNumber = 1,
    this.maxPages = 1,
    required this.data,
  });

  List<int> build() {
    return [
      command.value,
      seq & 0xFF,
      totalPackages & 0xFF,
      currentPackage & 0xFF,
      screenStatus & 0xFF,
      newCharPos0 & 0xFF,
      newCharPos1 & 0xFF,
      pageNumber & 0xFF,
      maxPages & 0xFF,
      ...data,
    ];
  }
}

// Define AIStatus and ScreenAction constants
class AIStatus {
  static const int DISPLAYING = 0x20;
  static const int DISPLAY_COMPLETE = 0x40;
}

class ScreenAction {
  static const int NEW_CONTENT = 0x10;
}

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

List<String> formatTextLines(String textMessage) {
  // Assuming a maximum line length of 20 characters
  const int maxLineLength = 20;
  List<String> words = textMessage.split(' ');
  List<String> lines = [];
  String currentLine = '';

  for (String word in words) {
    if ((currentLine + word).length <= maxLineLength) {
      currentLine += (currentLine.isEmpty ? '' : ' ') + word;
    } else {
      lines.add(currentLine);
      currentLine = word;
    }
  }
  if (currentLine.isNotEmpty) {
    lines.add(currentLine);
  }
  return lines;
}

Future<List<int>?> sendBmpPacket({
  required Uint8List dataChunk,
  required BluetoothManager bluetoothManager,
  int seq = 0,
}) async {
  BmpPacket result = BmpPacket(
    command: Command.BMP,
    seq: seq,
    data: dataChunk,
  );

  List<int> bmpCommand = result.build();

  if (seq == 0) {
    // Insert the 4 required bytes
    bmpCommand.insertAll(2, [0x00, 0x1c, 0x00, 0x00]);
    print(bmpCommand);
  }

  try {
    if (bluetoothManager.leftGlass != null &&
        bluetoothManager.rightGlass != null) {
      // Send to the left glass and wait
      await bluetoothManager.leftGlass!.sendData(bmpCommand);

      // Send to the right glass and wait
      await bluetoothManager.rightGlass!.sendData(bmpCommand);

      return bmpCommand;
    } else {
      print("Could not connect to glasses devices.");
      return null;
    }
  } catch (e) {
    print('Error in sendTextPacket: $e');
    return null;
  }
}

Future<bool?> sendPacketEndPacket({
  required BluetoothManager bluetoothManager,
}) async {
  try {
    if (bluetoothManager.leftGlass != null &&
        bluetoothManager.rightGlass != null) {
      // Send to the left glass and wait
      await bluetoothManager.leftGlass!.sendData([0x20, 0x0d, 0x0e]);

      // Send to the right glass and wait
      await bluetoothManager.rightGlass!.sendData([0x20, 0x0d, 0x0e]);

      return true;
    } else {
      print("Could not connect to glasses devices.");
      return null;
    }
  } catch (e) {
    print('Error in sendTextPacket: $e');
    return false;
  }
}

int _crc32(Uint8List data) {
  var crc = Crc32();
  crc.add(data);
  return crc.close();
}

Future<List<int>?> sendCRCPacket({
  required Uint8List packets,
  required BluetoothManager bluetoothManager,
  int seq = 0,
}) async {
  Uint8List crcData = Uint8List.fromList([...packets]);

  int crc32Checksum = _crc32(crcData) & 0xFFFFFFFF;
  Uint8List crc32Bytes = Uint8List(4);
  crc32Bytes[0] = (crc32Checksum >> 24) & 0xFF;
  crc32Bytes[1] = (crc32Checksum >> 16) & 0xFF;
  crc32Bytes[2] = (crc32Checksum >> 8) & 0xFF;
  crc32Bytes[3] = crc32Checksum & 0xFF;

  CrcPacket result = CrcPacket(
    command: Command.CRC,
    data: crc32Bytes,
  );

  List<int> crcCommand = result.build();

  try {
    if (bluetoothManager.leftGlass != null &&
        bluetoothManager.rightGlass != null) {
      // Send to the left glass and wait
      await bluetoothManager.leftGlass!.sendData(crcCommand);

      // Send to the right glass and wait
      await bluetoothManager.rightGlass!.sendData(crcCommand);

      return crcCommand;
    } else {
      print("Could not connect to glasses devices.");
      return null;
    }
  } catch (e) {
    print('Error in sendTextPacket: $e');
    return null;
  }
}

Future<String?> sendTextPacket({
  required String textMessage,
  required BluetoothManager bluetoothManager,
  int pageNumber = 1,
  int maxPages = 1,
  int screenStatus = ScreenAction.NEW_CONTENT | AIStatus.DISPLAYING,
  int delay = 400,
  int seq = 0,
}) async {
  List<int> textBytes = utf8.encode(textMessage);

  SendResultPacket result = SendResultPacket(
    command: Command.SEND_RESULT,
    seq: seq,
    totalPackages: 1,
    currentPackage: 0,
    screenStatus: screenStatus,
    newCharPos0: 0,
    newCharPos1: 0,
    pageNumber: pageNumber,
    maxPages: maxPages,
    data: textBytes,
  );

  List<int> aiResultCommand = result.build();

  try {
    if (bluetoothManager.leftGlass != null &&
        bluetoothManager.rightGlass != null) {
      // Send to the left glass and wait
      await bluetoothManager.leftGlass!.sendData(aiResultCommand);
      await Future.delayed(Duration(milliseconds: delay));

      // Send to the right glass and wait
      await bluetoothManager.rightGlass!.sendData(aiResultCommand);
      await Future.delayed(Duration(milliseconds: delay));

      return textMessage;
    } else {
      print("Could not connect to glasses devices.");
      return null;
    }
  } catch (e) {
    print('Error in sendTextPacket: $e');
    return null;
  }
}

Future<Uint8List?> sendBitmap(
    Uint8List bitmap, BluetoothManager bluetoothManager) async {
  List<Uint8List> textBytes = Utils.divideUint8List(bitmap, 194);

  List<List<int>?> sentPackets = [];

  print("Transmitting BMP");
  for (int i = 0; i < textBytes.length; i++) {
    sentPackets.add(await sendBmpPacket(
        dataChunk: textBytes[i], bluetoothManager: bluetoothManager, seq: i));
    await Future.delayed(Duration(milliseconds: 100));
  }

  print("Send end packet");
  await sendPacketEndPacket(bluetoothManager: bluetoothManager);
  await Future.delayed(Duration(milliseconds: 500));

  List<int> concatenatedList = [];
  for (var packet in sentPackets) {
    if (packet != null) {
      concatenatedList.addAll(packet);
    }
  }
  Uint8List concatenatedPackets = Uint8List.fromList(concatenatedList);

  print("Sending CRC for mitmap");
  // Send CRC
  await sendCRCPacket(
      packets: concatenatedPackets, bluetoothManager: bluetoothManager);

  return concatenatedPackets;
}

Future<String?> sendText(String textMessage, BluetoothManager bluetoothManager,
    {double duration = 5.0}) async {
  List<String> lines = formatTextLines(textMessage);
  int totalPages = ((lines.length + 4) / 5).ceil(); // 5 lines per page

  if (totalPages > 1) {
    print("Sending $totalPages pages with $duration seconds delay");
    int screenStatus = AIStatus.DISPLAYING | ScreenAction.NEW_CONTENT;

    await sendTextPacket(
      textMessage: lines[0],
      bluetoothManager: bluetoothManager,
      pageNumber: 1,
      maxPages: totalPages,
      screenStatus: screenStatus,
    );
    await Future.delayed(Duration(milliseconds: 100));
  }

  String lastPageText = '';

  for (int pn = 1, page = 0; page < lines.length; pn++, page += 5) {
    List<String> pageLines = lines.sublist(
      page,
      (page + 5) > lines.length ? lines.length : (page + 5),
    );

    // Add vertical centering for pages with fewer than 5 lines
    if (pageLines.length < 5) {
      int padding = ((5 - pageLines.length) / 2).floor();
      pageLines = List.filled(padding, '') +
          pageLines +
          List.filled(5 - pageLines.length - padding, '');
    }

    String text = pageLines.join('\n');
    lastPageText = text;
    int screenStatus = AIStatus.DISPLAYING | ScreenAction.NEW_CONTENT;

    await sendTextPacket(
      textMessage: text,
      bluetoothManager: bluetoothManager,
      pageNumber: pn,
      maxPages: totalPages,
      screenStatus: screenStatus,
    );

    // Wait after sending each page except the last one
    if (pn != totalPages) {
      await Future.delayed(Duration(seconds: duration.ceil()));
    }
  }

  // After all pages, send the last page again with DISPLAY_COMPLETE status
  int screenStatus = AIStatus.DISPLAY_COMPLETE;

  await sendTextPacket(
    textMessage: lastPageText,
    bluetoothManager: bluetoothManager,
    pageNumber: totalPages,
    maxPages: totalPages,
    screenStatus: screenStatus,
  );

  return textMessage;
}
