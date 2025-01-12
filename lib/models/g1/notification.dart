import 'dart:convert';
import 'dart:typed_data';

import 'package:fahrplan/utils/emoji.dart';
import 'package:intl/intl.dart';

class G1Notification {
  final NCSNotification ncsNotification;
  final String type;

  G1Notification({
    required this.ncsNotification,
    this.type = "Add",
  });

  Map<String, dynamic> toJson() {
    return {
      'ncs_notification': ncsNotification.toJson(),
      // 'type': type,
    };
  }

  Uint8List toBytes() {
    return Uint8List.fromList(utf8.encode(jsonEncode(toJson())));
  }

  Future<List<Uint8List>> constructNotification() async {
    ncsNotification.message = Emoji.emojiToAscii(ncsNotification.message);
    ncsNotification.title = Emoji.emojiToAscii(ncsNotification.title);
    ncsNotification.subtitle = Emoji.emojiToAscii(ncsNotification.subtitle);
    Uint8List jsonBytes = toBytes();

    int maxChunkSize = 180 - 4; // Subtract 4 bytes for header
    List<Uint8List> chunks = [];

    for (int i = 0; i < jsonBytes.length; i += maxChunkSize) {
      int end = (i + maxChunkSize < jsonBytes.length)
          ? i + maxChunkSize
          : jsonBytes.length;
      chunks.add(jsonBytes.sublist(i, end));
    }

    int totalChunks = chunks.length;
    List<Uint8List> encodedChunks = [];
    for (int index = 0; index < chunks.length; index++) {
      int notifyId = 1; // Set appropriate notification ID
      List<int> header = [0x4B, notifyId, totalChunks, index];
      Uint8List encodedChunk = Uint8List.fromList(header + chunks[index]);
      encodedChunks.add(encodedChunk);
    }
    return encodedChunks;
  }
}

class NCSNotification {
  final int msgId;
  final int action;
  final int type;
  final String appIdentifier;
  String title;
  String subtitle;
  String message;
  final int timeS;
  final String date;
  final String displayName;

  NCSNotification({
    required this.msgId,
    this.type = 1,
    required this.appIdentifier,
    required this.title,
    required this.subtitle,
    required this.message,
    this.action = 0,
    int? timeS,
    String? date,
    required this.displayName,
  })  : timeS = timeS ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
        date = date ?? DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

  Map<String, dynamic> toJson() {
    return {
      'msg_id': msgId,
      'action': action,
      //'type': type,
      'app_identifier': appIdentifier,
      'title': title,
      'subtitle': subtitle,
      'message': message,
      'time_s': timeS,
      'date': date,
      'display_name': displayName,
    };
  }
}
