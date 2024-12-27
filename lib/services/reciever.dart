import 'dart:typed_data';

import 'package:fahrplan/models/g1/glass.dart';

// Command response status codes
const int RESPONSE_SUCCESS = 0xC9;
const int RESPONSE_FAILURE = 0xCA;

// Voice data buffer to collect chunks
class VoiceDataCollector {
  final Map<int, List<int>> _chunks = {};
  int _expectedSeq = 0;

  void addChunk(int seq, List<int> data) {
    _chunks[seq] = data;
  }

  bool get isComplete =>
      _chunks.isNotEmpty && !_chunks.containsKey(_expectedSeq);

  List<int> getAllData() {
    List<int> complete = [];
    for (var i = 0; i < _chunks.length; i++) {
      if (_chunks.containsKey(i)) {
        complete.addAll(_chunks[i]!);
      }
    }
    return complete;
  }

  void reset() {
    _chunks.clear();
    _expectedSeq = 0;
  }
}

final VoiceDataCollector voiceCollector = VoiceDataCollector();

Future<void> receiveHandler(GlassSide side, List<int> data) async {
  if (data.isEmpty) return;

  int command = data[0];

  switch (command) {
    case 0xF5: // Start Even AI
      if (data.length >= 2) {
        int subcmd = data[1];
        handleEvenAICommand(side, subcmd);
      }
      break;

    case 0x0E: // Mic Response
      if (data.length >= 3) {
        int status = data[1];
        int enable = data[2];
        handleMicResponse(side, status, enable);
      }
      break;

    case 0xF1: // Voice Data
      if (data.length >= 2) {
        int seq = data[1];
        List<int> voiceData = data.sublist(2);
        handleVoiceData(side, seq, voiceData);
      }
      break;

    default:
      print('[$side] Unknown command: 0x${command.toRadixString(16)}');
  }
}

void handleEvenAICommand(GlassSide side, int subcmd) {
  switch (subcmd) {
    case 0:
      print('[$side] Exit to dashboard manually');
      break;
    case 1:
      print('[$side] Page ${side == 'left' ? 'up' : 'down'} control');
      break;
    case 23:
      print('[$side] Start Even AI');
      break;
    case 24:
      print('[$side] Stop Even AI recording');
      // Process collected voice data
      if (voiceCollector.isComplete) {
        List<int> completeVoiceData = voiceCollector.getAllData();
        // TODO: Process voice data (LC3 format)
        voiceCollector.reset();
      }
      break;
  }
}

void handleMicResponse(GlassSide side, int status, int enable) {
  if (status == RESPONSE_SUCCESS) {
    print('[$side] Mic ${enable == 1 ? "enabled" : "disabled"} successfully');
  } else if (status == RESPONSE_FAILURE) {
    print('[$side] Failed to ${enable == 1 ? "enable" : "disable"} mic');
  }
}

void handleVoiceData(GlassSide side, int seq, List<int> voiceData) {
  print(
      '[$side] Received voice data chunk: seq=$seq, length=${voiceData.length}');
  voiceCollector.addChunk(seq, voiceData);
}
