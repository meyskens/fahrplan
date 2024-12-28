import 'dart:convert';
import 'dart:typed_data';

import 'package:fahrplan/models/g1/commands.dart';

class NoteConstants {
  static const int FIXED_BYTE = 0x00;
  static const int FIXED_BYTE_2 = 0x01;
}

// NoteSupportedIcons class is used to store the supported icons in notes as observed
// to be supported in the official ER app.
class NoteSupportedIcons {
  static const String CHECKBOX = '☐';
  static const String CHECK = '​✓';
}

class Note {
  int noteNumber;
  final String name;
  final String text;

  Note({
    required this.noteNumber,
    required this.name,
    required this.text,
  }) {
    if (noteNumber < 1 || noteNumber > 4) {
      throw ArgumentError('Note number must be between 1 and 4');
    }
  }

  Uint8List _getFixedBytes() {
    return Uint8List.fromList([0x03, 0x01, 0x00, 0x01, 0x00]);
  }

  int _getVersioningByte() {
    return DateTime.now().millisecondsSinceEpoch ~/ 1000 % 256;
  }

  int _calculatePayloadLength(Uint8List nameBytes, Uint8List textBytes) {
    List<int> components = [
      1, // Fixed byte
      1, // Versioning byte
      _getFixedBytes().length, // Fixed bytes sequence
      1, // Note number
      1, // Fixed byte 2
      1, // Title length
      nameBytes.length, // Title bytes
      1, // Text length
      1, // Fixed byte after text length
      textBytes.length, // Text bytes
      2, // Final bytes
    ];
    return components.reduce((a, b) => a + b);
  }

  Uint8List buildAddCommand() {
    Uint8List nameBytes = Uint8List.fromList(utf8.encode(name));
    Uint8List textBytes = Uint8List.fromList(utf8.encode(text));

    int payloadLength = _calculatePayloadLength(nameBytes, textBytes);
    int versioningByte = _getVersioningByte();
    Uint8List fixedBytes = _getFixedBytes();

    List<int> command = [
          Commands.QUICK_NOTE_ADD,
          payloadLength & 0xFF,
          NoteConstants.FIXED_BYTE,
          versioningByte,
        ] +
        fixedBytes +
        [
          noteNumber,
          NoteConstants.FIXED_BYTE_2,
          nameBytes.length & 0xFF,
        ] +
        nameBytes +
        [
          textBytes.length & 0xFF,
          NoteConstants.FIXED_BYTE,
        ] +
        textBytes;

    return Uint8List.fromList(command);
  }
}
