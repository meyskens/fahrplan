import 'dart:convert';
import 'package:intl/intl.dart';
import '../services/commands.dart';

class NCSNotification {
  final int msgId;
  final int type;
  final String appIdentifier;
  final String title;
  final String subtitle;
  final String message;
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
    int? timeS,
    String? date,
    required this.displayName,
  })  : timeS = timeS ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000),
        date = date ?? DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

  Map<String, dynamic> toJson() => {
        'msg_id': msgId,
        'type': type,
        'app_identifier': appIdentifier,
        'title': title,
        'subtitle': subtitle,
        'message': message,
        'time_s': timeS,
        'date': date,
        'display_name': displayName,
      };

  factory NCSNotification.fromJson(Map<String, dynamic> json) => NCSNotification(
        msgId: json['msg_id'],
        type: json['type'],
        appIdentifier: json['app_identifier'],
        title: json['title'],
        subtitle: json['subtitle'],
        message: json['message'],
        timeS: json['time_s'],
        date: json['date'],
        displayName: json['display_name'],
      );
}

class Notification {
  final NCSNotification ncsNotification;
  final String type;

  Notification({
    required this.ncsNotification,
    this.type = 'Add',
  });

  Map<String, dynamic> toJson() => {
        'ncs_notification': ncsNotification.toJson(),
        'type': type,
      };

  List<int> toBytes() {
    return utf8.encode(jsonEncode(toJson()));
  }

  Future<List<List<int>>> constructNotification() async {
    final List<int> jsonBytes = toBytes();
    const int maxChunkSize = 180 - 4;  // Subtract 4 bytes for header
    final List<List<int>> chunks = [];
    
    // Split into chunks
    for (var i = 0; i < jsonBytes.length; i += maxChunkSize) {
      chunks.add(
        jsonBytes.sublist(
          i,
          i + maxChunkSize > jsonBytes.length ? jsonBytes.length : i + maxChunkSize,
        ),
      );
    }

    final int totalChunks = chunks.length;
    final List<List<int>> encodedChunks = [];

    // Create chunks with proper 4-byte header
    for (var i = 0; i < chunks.length; i++) {
      const int notifyId = 0;  // Set appropriate notification ID
      final List<int> header = [
        Command.NOTIFICATION.value,  // notification command
        notifyId,                   // notification ID
        totalChunks,               // total chunks
        i,                         // chunk index
      ];
      encodedChunks.add([...header, ...chunks[i]]);
    }

    return encodedChunks;
  }
}
