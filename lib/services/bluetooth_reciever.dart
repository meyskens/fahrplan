import 'dart:convert';
import 'dart:io';

import 'package:fahrplan/models/fahrplan/whispermodel.dart';
import 'package:fahrplan/models/fahrplan/widgets/homassistant.dart';
import 'package:fahrplan/models/g1/even_ai.dart';
import 'package:fahrplan/models/g1/glass.dart';
import 'package:fahrplan/models/g1/commands.dart';
import 'package:fahrplan/models/g1/text.dart';
import 'package:fahrplan/services/bluetooth_manager.dart';
import 'package:fahrplan/utils/lc3.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:whisper_flutter_new/whisper_flutter_new.dart';

// Command response status codes
const int RESPONSE_SUCCESS = 0xC9;
const int RESPONSE_FAILURE = 0xCA;

class BluetoothReciever {
  static final BluetoothReciever singleton = BluetoothReciever._internal();

  final voiceCollector = VoiceDataCollector();

  factory BluetoothReciever() {
    return singleton;
  }

  BluetoothReciever._internal();

  Future<void> receiveHandler(GlassSide side, List<int> data) async {
    if (data.isEmpty) return;

    int command = data[0];

    switch (command) {
      case Commands.HEARTBEAT:
        break;
      case Commands.START_AI:
        if (data.length >= 2) {
          int subcmd = data[1];
          handleEvenAICommand(side, subcmd);
        }
        break;

      case Commands.MIC_RESPONSE: // Mic Response
        if (data.length >= 3) {
          int status = data[1];
          int enable = data[2];
          handleMicResponse(side, status, enable);
        }
        break;

      case Commands.RECEIVE_MIC_DATA: // Voice Data
        if (data.length >= 2) {
          int seq = data[1];
          List<int> voiceData = data.sublist(2);
          handleVoiceData(side, seq, voiceData);
        }
        break;

      default:
        debugPrint('[$side] Unknown command: 0x${command.toRadixString(16)}');
    }
  }

  void handleEvenAICommand(GlassSide side, int subcmd) async {
    final bt = BluetoothManager();
    switch (subcmd) {
      case 0:
        debugPrint('[$side] Exit to dashboard manually');
        await bt.setMicrophone(false);
        voiceCollector.isRecording = false;
        break;
      case 1:
        debugPrint('[$side] Page ${side == 'left' ? 'up' : 'down'} control');
        await bt.setMicrophone(false);
        voiceCollector.isRecording = false;
        break;
      case 23:
        debugPrint('[$side] Start Even AI');
        voiceCollector.isRecording = true;
        await bt.setMicrophone(true);
        break;
      case 24:
        debugPrint('[$side] Stop Even AI recording');
        voiceCollector.isRecording = false;
        await bt.setMicrophone(false);

        List<int> completeVoiceData = voiceCollector.getAllData();
        if (completeVoiceData.isEmpty) {
          debugPrint('[$side] No voice data collected');
          return;
        }
        voiceCollector.reset();
        debugPrint(
            '[$side] Voice data collected: ${completeVoiceData.length} bytes');

        final pcm = await LC3.decodeLC3(Uint8List.fromList(completeVoiceData));

        debugPrint('[$side] Voice data decoded: ${pcm.length} bytes');

        final startTime = DateTime.now();
        final transcription = await transcribe(pcm);
        final endTime = DateTime.now();

        debugPrint('[$side] Transcription: $transcription');
        debugPrint(
            '[$side] Transcription took: ${endTime.difference(startTime).inSeconds} seconds');

        final HomeAssistantWidget ha = HomeAssistantWidget();
        final resp = await ha.handleQuery(transcription);
        await bt.sendText(resp);
        break;

      default:
        debugPrint('[$side] Unknown Even AI subcommand: $subcmd');
      //await bt.setMicrophone(false);
    }
  }

  void handleMicResponse(GlassSide side, int status, int enable) {
    if (status == RESPONSE_SUCCESS) {
      debugPrint(
          '[$side] Mic ${enable == 1 ? "enabled" : "disabled"} successfully');
    } else if (status == RESPONSE_FAILURE) {
      debugPrint('[$side] Failed to ${enable == 1 ? "enable" : "disable"} mic');
      final bt = BluetoothManager();
      bt.setMicrophone(enable == 1);
    }
  }

  void handleVoiceData(GlassSide side, int seq, List<int> voiceData) {
    debugPrint(
        '[$side] Received voice data chunk: seq=$seq, length=${voiceData.length}');
    voiceCollector.addChunk(seq, voiceData);
    final bt = BluetoothManager();
    if (!voiceCollector.isRecording) {
      bt.setMicrophone(false);
    }
  }

  Future<String> transcribe(Uint8List voiceData) async {
    final Directory documentDirectory =
        await getApplicationDocumentsDirectory();
    // Prepare wav file

    final String wavPath = '${documentDirectory.path}/${Uuid().v4()}.wav';
    debugPrint('Wav path: $wavPath');

    // Add wav header
    final int sampleRate = 16000;
    final int numChannels = 1;
    final int byteRate = sampleRate * numChannels * 2;
    final int blockAlign = numChannels * 2;
    final int bitsPerSample = 16;
    final int dataSize = voiceData.length;
    final int chunkSize = 36 + dataSize;

    final List<int> header = [
      // RIFF header
      ...ascii.encode('RIFF'),
      chunkSize & 0xff,
      (chunkSize >> 8) & 0xff,
      (chunkSize >> 16) & 0xff,
      (chunkSize >> 24) & 0xff,
      // WAVE header
      ...ascii.encode('WAVE'),
      // fmt subchunk
      ...ascii.encode('fmt '),
      16, 0, 0, 0, // Subchunk1Size (16 for PCM)
      1, 0, // AudioFormat (1 for PCM)
      numChannels, 0, // NumChannels
      sampleRate & 0xff,
      (sampleRate >> 8) & 0xff,
      (sampleRate >> 16) & 0xff,
      (sampleRate >> 24) & 0xff,
      byteRate & 0xff,
      (byteRate >> 8) & 0xff,
      (byteRate >> 16) & 0xff,
      (byteRate >> 24) & 0xff,
      blockAlign, 0,
      bitsPerSample, 0,
      // data subchunk
      ...ascii.encode('data'),
      dataSize & 0xff,
      (dataSize >> 8) & 0xff,
      (dataSize >> 16) & 0xff,
      (dataSize >> 24) & 0xff,
    ];
    header.addAll(voiceData.toList());

    await File(wavPath).writeAsBytes(Uint8List.fromList(header));

    SharedPreferences prefs = await SharedPreferences.getInstance();

    final Whisper whisper = Whisper(
        model:
            FahrplanWhisperModel(prefs.getString('whisper_model') ?? '').model,
        downloadHost:
            "https://huggingface.co/ggerganov/whisper.cpp/resolve/main");

    final String? whisperVersion = await whisper.getVersion();
    debugPrint(whisperVersion);

    final transcription = await whisper.transcribe(
      transcribeRequest: TranscribeRequest(
        audio: wavPath,
        isTranslate: false,
        isNoTimestamps: true,
        splitOnWord: true,
        diarize: false,
        isSpecialTokens: false,
        nProcessors: 2,
      ),
    );
    // remove all [.*] tags
    transcription.text = transcription.text.replaceAll(RegExp(r'\[.*?\]'), '');
    // remove all double spaces
    transcription.text = transcription.text.replaceAll(RegExp(r' {2,}'), ' ');
    return transcription.text;
  }
}

// Voice data buffer to collect chunks
class VoiceDataCollector {
  final Map<int, List<int>> _chunks = {};
  int seqAdd = 0;

  bool isRecording = false;

  void addChunk(int seq, List<int> data) {
    if (seq == 255) {
      seqAdd += 255;
    }
    _chunks[seqAdd + seq] = data;
  }

  List<int> getAllData() {
    List<int> complete = [];
    final keys = _chunks.keys.toList()..sort();

    for (int key in keys) {
      complete.addAll(_chunks[key]!);
    }
    return complete;
  }

  void reset() {
    _chunks.clear();
    seqAdd = 0;
  }
}
