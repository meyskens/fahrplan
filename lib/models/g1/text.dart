import 'dart:convert';

import 'package:fahrplan/models/g1/commands.dart';
import 'package:fahrplan/models/g1/even_ai.dart';
import 'package:flutter/foundation.dart';

// Define AIStatus and ScreenAction constants
class AIStatus {
  static const int DISPLAYING = 0x20;
  static const int DISPLAY_COMPLETE = 0x40;
}

class ScreenAction {
  static const int NEW_CONTENT = 0x10;
}

class TextMessage {
  final String text;

  TextMessage(this.text);

  List<int> _sendTextPacket({
    required String textMessage,
    int pageNumber = 1,
    int maxPages = 1,
    int screenStatus = ScreenAction.NEW_CONTENT | AIStatus.DISPLAYING,
    int seq = 0,
  }) {
    List<int> textBytes = utf8.encode(textMessage);

    SendResultPacket result = SendResultPacket(
      command: Commands.SEND_RESULT,
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

    return result.build();
  }

  List<String> _formatTextLines(String textMessage) {
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

  List<List<int>> constructSendText() {
    List<String> lines = _formatTextLines(text);
    int totalPages = ((lines.length + 4) / 5).ceil(); // 5 lines per page

    List<List<int>> packets = [];

    if (totalPages > 1) {
      debugPrint("Composeing $totalPages pages");
      int screenStatus = AIStatus.DISPLAYING | ScreenAction.NEW_CONTENT;

      packets.add(_sendTextPacket(
        textMessage: lines[0],
        pageNumber: 1,
        maxPages: totalPages,
        screenStatus: screenStatus,
      ));
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

      packets.add(_sendTextPacket(
        textMessage: text,
        pageNumber: pn,
        maxPages: totalPages,
        screenStatus: screenStatus,
      ));
    }

    // After all pages, send the last page again with DISPLAY_COMPLETE status
    int screenStatus = AIStatus.DISPLAY_COMPLETE;

    packets.add(_sendTextPacket(
      textMessage: lastPageText,
      pageNumber: totalPages,
      maxPages: totalPages,
      screenStatus: screenStatus,
    ));

    return packets;
  }
}
