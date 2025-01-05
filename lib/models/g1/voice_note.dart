import 'dart:typed_data';

import 'package:fahrplan/models/g1/commands.dart';
import 'package:flutter/foundation.dart';

class NoteSubCommands {
  static const int REQUEST_AUDIO_INFO = 0x01;
  static const int REQUEST_AUDIO_DATA = 0x02;
  //static const int CREATE_UPDATE_DELETE_NOTE = 0x03; // used for text
  static const int DELETE_AUDIO_STREAM = 0x04;
  static const int DELETE_ALL = 0x05;
}

class VoiceNote {
  int index;
  int? timestamp;
  int? crc;

  VoiceNote({
    required this.index,
    this.timestamp,
    this.crc,
  });

  Uint8List buildFetchCommand(int syncid) {
    return Uint8List.fromList([
      Commands.QUICK_NOTE_ADD,
      0x06,
      0x00,
      syncid,
      NoteSubCommands.REQUEST_AUDIO_DATA,
      index
    ]);
  }

  Uint8List buildDeleteCommand(int syncid) {
    return Uint8List.fromList([
      Commands.QUICK_NOTE_ADD,
      0x06,
      0x00,
      syncid,
      NoteSubCommands.DELETE_AUDIO_STREAM,
      index
    ]);
  }
}

class VoiceNoteNotification {
  Uint8List data;
  List<VoiceNote> entries = [];

  VoiceNoteNotification(this.data) {
    /*
     0 21 
     1 2a = packet length (42)
     2 00 = null
     3 07 = sync id
     4 01 = unknown
     5 04 = num of notes
     6 01 = index
       9a a1 7a 67 = timestamp32
       77 0a 84 bb = crc32
       
       02 
       23 a2 7a 67 
       a9 73 5a a5 
       
       03 
       18 a3 7a 67 
       f1 8f 9e 2c 
       
       04 
       7a a3 7a 67 
       de ef 2a 85
     */
    if (data.length < 6) return;
    if (data[0] != Commands.QUICK_NOTE) return;
    int length = data[1] + (data[2] << 8);

    double numNotesLength = (length - 6) / 9;
    if (numNotesLength % 1 != 0) throw Exception('Invalid data length');
    int numNotes = data[5];
    if (numNotes != numNotesLength) throw Exception('Invalid data length');

    for (int i = 0; i < numNotes; i++) {
      int index = data[6 + i * 9];
      List<int> timestampBytes = data.sublist(7 + i * 9, 11 + i * 9);
      int timestamp = timestampBytes[0] +
          (timestampBytes[1] << 8) +
          (timestampBytes[2] << 16) +
          (timestampBytes[3] << 24);

      List<int> crcBytes = data.sublist(11 + i * 9, 15 + i * 9);
      int crc = crcBytes[0] +
          (crcBytes[1] << 8) +
          (crcBytes[2] << 16) +
          (crcBytes[3] << 24);

      entries.add(VoiceNote(index, timestamp, crc));
    }
  }
}
