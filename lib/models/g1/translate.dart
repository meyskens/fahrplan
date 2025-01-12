// ignore_for_file: non_constant_identifier_names

/*
Not much is known yet about these commands.
PRs to help document these magic numbers are very welcome!!
*/

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

class TranslateLanguages {
  // if you know any more please PR!
  static int CHINESE = 0x01;
  static int ENGLISH = 0x02;
  static int DUTCH = 0x09;
  static int FRENCH = 0x05;
}

class Translate {
  final int fromLanguage;
  final int toLanguage;

  int _syncId = 0;
  int syncId() {
    _syncId++;
    if (_syncId > 255) {
      _syncId = 0;
    }
    return _syncId;
  }

  Translate({required this.fromLanguage, required this.toLanguage});

  Uint8List buildSetupCommand() {
    return Uint8List.fromList([0x39, 0x05, 0x00, 0x00, 0x13]);
  }

  Uint8List buildRightGlassStartCommand() {
    return Uint8List.fromList([
      0x50, // start of translate
      0x06, // length
      0x00,
      0x00,
      0x01,
      0x01
    ]);
  }

  List<Uint8List> buildInitalScreenLoad() {
    return [
      Uint8List.fromList([0x1c, 0x00, fromLanguage, toLanguage]),
      Uint8List.fromList([
        0x0f, // original text
        syncId(),
        0x01, // set text
        0x00,
        0x00,
        0x00,
        0x00,
        0x0D,
      ]), // start text sequence
      Uint8List.fromList([
        0x0d, // translated text
        syncId(),
        0x01, // set text
        0x00,
        0x00,
        0x00,
        0x00,
        0x0D,
      ]) // start text sequence
    ];
  }

  Uint8List buildTranslatedCommand(String text) {
    return Uint8List.fromList([
      0x0d, // translated text command
      syncId(),
      0x01, // set text
      0x00,
      0x00,
      0x00,
      0x20,
      0x0D,
      ...utf8.encode(text)
    ]);
  }

  Uint8List buildOriginalCommand(String text) {
    return Uint8List.fromList([
      0x0f, // translated text command
      syncId(),
      0x01, // set text
      0x00,
      0x00,
      0x00,
      0x20,
      0x0D,
      ...utf8.encode(text)
    ]);
  }
}
