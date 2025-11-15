import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fahrplan/models/fahrplan/widgets/homassistant.dart';
import 'package:fahrplan/models/g1/glass.dart';
import 'package:fahrplan/models/g1/commands.dart';
import 'package:fahrplan/models/g1/voice_note.dart';
import 'package:fahrplan/services/bluetooth_manager.dart';
import 'package:fahrplan/services/whisper.dart';
import 'package:fahrplan/utils/lc3.dart';
import 'package:fahrplan/utils/wakeword_settings.dart';
import 'package:fahrplan/utils/wakeword_engine.dart';
import 'package:fahrplan/voice/voicecontrol.dart';
import 'package:flutter/foundation.dart';
import 'package:mutex/mutex.dart';

// Command response status codes
const int RESPONSE_SUCCESS = 0xC9;
const int RESPONSE_FAILURE = 0xCA;

class BluetoothReciever {
  static final BluetoothReciever singleton = BluetoothReciever._internal();

  final voiceCollectorAI = VoiceDataCollector();
  final voiceCollectorNote = VoiceDataCollector();
  late final VoiceDataCollector voiceCollectorWakeWord;

  int _syncId = 0;

  factory BluetoothReciever() {
    return singleton;
  }

  BluetoothReciever._internal() {
    voiceCollectorWakeWord = VoiceDataCollector(
      detectWakeWord: true,
      onWakeWordDetected: () {
        debugPrint('Wake word detected - starting voice control');
        Voicecontrol().startVoiceControl();
      },
    );
  }

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
      case Commands.QUICK_NOTE:
        handleQuickNoteCommand(side, data);
        break;
      case Commands.QUICK_NOTE_ADD:
        handleQuickNoteAudioData(side, data);
        break;

      default:
      //debugPrint('[$side] Unknown command: 0x${command.toRadixString(16)}');
    }
  }

  void handleEvenAICommand(GlassSide side, int subcmd) async {
    final bt = BluetoothManager();
    switch (subcmd) {
      case 0:
        debugPrint('[$side] Exit to dashboard manually');
        await bt.setMicrophone(false);
        voiceCollectorAI.isRecording = false;
        voiceCollectorAI.reset();

        voiceCollectorWakeWord.isRecording = false;
        voiceCollectorWakeWord.reset();
        break;
      case 1:
        debugPrint('[$side] Page ${side == 'left' ? 'up' : 'down'} control');
        await bt.setMicrophone(false);
        voiceCollectorAI.isRecording = false;

        voiceCollectorWakeWord.isRecording = false;
        voiceCollectorWakeWord.reset();
        break;
      case 2:
        debugPrint('[$side] Start wake word detection');
        voiceCollectorWakeWord.isRecording = true;
        break;
      case 3:
        debugPrint('[$side] Stop wake word detection');
        voiceCollectorWakeWord.isRecording = false;
        voiceCollectorWakeWord.reset();
        break;
      case 23:
        debugPrint('[$side] Start Even AI');
        voiceCollectorWakeWord.isRecording = false;
        voiceCollectorWakeWord.reset();

        voiceCollectorAI.isRecording = true;
        await bt.setMicrophone(true);
        break;
      case 24:
        debugPrint('[$side] Stop Even AI recording');
        voiceCollectorWakeWord.isRecording = false;
        voiceCollectorWakeWord.reset();

        voiceCollectorAI.isRecording = false;
        await bt.setMicrophone(false);

        List<int> completeVoiceData = voiceCollectorAI.getAllData();
        if (completeVoiceData.isEmpty) {
          debugPrint('[$side] No voice data collected');
          return;
        }
        voiceCollectorAI.reset();
        debugPrint(
            '[$side] Voice data collected: ${completeVoiceData.length} bytes');

        final pcm = await LC3.decodeLC3(Uint8List.fromList(completeVoiceData));

        debugPrint('[$side] Voice data decoded: ${pcm.length} bytes');

        final startTime = DateTime.now();
        final transcription =
            await (await WhisperService.service()).transcribe(pcm);
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
    //debugPrint(
    //    '[$side] Received voice data chunk: seq=$seq, length=${voiceData.length}');
    if (voiceCollectorAI.isRecording) {
      voiceCollectorAI.addChunk(seq, voiceData);
    } else if (voiceCollectorWakeWord.isRecording) {
      voiceCollectorWakeWord.addChunk(seq, voiceData);
    }
    final bt = BluetoothManager();
    if (!voiceCollectorAI.isRecording && !voiceCollectorWakeWord.isRecording) {
      bt.setMicrophone(false);
    }
  }

  void handleQuickNoteCommand(GlassSide side, List<int> data) {
    try {
      final notif = VoiceNoteNotification(Uint8List.fromList(data));
      debugPrint('Voice note notification: ${notif.entries.length} entries');
      for (VoiceNote entry in notif.entries) {
        debugPrint(
            'Voice note: index=${entry.index}, timestamp=${entry.timestamp}');
      }
      if (notif.entries.isNotEmpty) {
        // fetch newest note
        voiceCollectorNote.reset();
        final entry = notif.entries.first;
        final bt = BluetoothManager();
        bt.rightGlass!.sendData(entry.buildFetchCommand(_syncId++));
      }
    } catch (e) {
      debugPrint('Failed to parse voice note notification: $e');
    }
  }

  void handleQuickNoteAudioData(GlassSide side, List<int> data) async {
    if (data.length > 4 && data[4] != 0x02) {
      //debugPrint('[$side] not an audio data packet');
      return;
    }
    /*  audio_response_packet_buf[0] = 0x1E;
    audio_response_packet_buf[1] = audio_chunk_size + 10; // total packet length
    audio_response_packet_buf[2] = 0; // possibly packet-length extended to uint16_t
    audio_response_packet_buf[3] = audio_sync_id++;
    audio_response_packet_buf[4] = 2; // unknown, always 2
    *(uint16_t*)&audio_response_packet_buf[5] = total_number_of_packets_for_audio;
    *(uint16_t*)&audio_response_packet_buf[7] = ++current_packet_number;
    audio_response_packet_buf[9] = audio_index_in_flash + 1;
    audio_response_packet_buf[10 .. n] = <audio-data>
    */
    if (data.length < 11) {
      final dataStr = data.map((e) => e.toRadixString(16)).join(' ');
      debugPrint('[$side] Invalid audio data packet: $dataStr');
      return;
    }

    int seq = data[3];
    int totalPackets = (data[5] << 8) | data[4];
    int currentPacket = (data[7] << 8) | data[6];
    int index = data[9] - 1;
    List<int> voiceData = data.sublist(10);

    debugPrint('[$side] Note Audio data packet: seq=$seq, total=$totalPackets, '
        'current=$currentPacket, length=${voiceData.length}');
    voiceCollectorNote.addChunk(seq, voiceData);

    if (currentPacket + 2 == totalPackets) {
      debugPrint('[$side] Last packet received');
      final completeVoiceData = voiceCollectorNote.getAllData();

      final pcm = await LC3.decodeLC3(Uint8List.fromList(completeVoiceData));

      debugPrint('[$side] Voice data decoded: ${pcm.length} bytes');

      voiceCollectorNote.reset();
      final bt = BluetoothManager();
      await bt.rightGlass!
          .sendData(VoiceNote(index: index + 1).buildDeleteCommand(_syncId++));

      final startTime = DateTime.now();
      final transcription =
          await (await WhisperService.service()).transcribe(pcm);
      final endTime = DateTime.now();

      debugPrint('[$side] Transcription: $transcription');
      debugPrint(
          '[$side] Transcription took: ${endTime.difference(startTime).inSeconds} seconds');
      try {
        Voicecontrol().launch(transcription);
      } catch (e) {
        bt.sendText(e.toString());
      }
    }
  }
}

// Voice data buffer to collect chunks
class VoiceDataCollector {
  final Map<int, List<int>> _chunks = {};
  int seqAdd = 0;
  final m = Mutex();

  bool isRecording = false;
  bool detectWakeWord = false;
  final void Function()? onWakeWordDetected;

  WakeWordDetector? _wakeWordDetector;
  Timer? _processPCMTicker;

  VoiceDataCollector({this.detectWakeWord = false, this.onWakeWordDetected});

  Future<void> _createDetector() async {
    try {
      _wakeWordDetector = await WakeWordDetector.create(
        onWakeWordDetected: onWakeWordDetected,
      );
      if (_wakeWordDetector != null) {
        await _wakeWordDetector!.initialize();
      }
    } catch (err) {
      debugPrint("Failed to create wake word detector: $err");
    }
  }

  Future<void> _handleWakeWord() async {
    try {
      final completeVoiceData = await getAllDataAndReset();
      if (completeVoiceData.isEmpty) {
        return;
      }
      final pcm = await LC3.decodeLC3(Uint8List.fromList(completeVoiceData));

      // Add wav header
      final int sampleRate = 16000;
      final int numChannels = 1;
      final int bitsPerSample = 16;
      final int byteRate = sampleRate * numChannels * (bitsPerSample ~/ 8);
      final int blockAlign = numChannels * (bitsPerSample ~/ 8);
      final int dataSize =
          pcm.length * 2; // PCM data is 16-bit, so 2 bytes per sample
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
        pcm.length & 0xff,
        (pcm.length >> 8) & 0xff,
        (pcm.length >> 16) & 0xff,
        (pcm.length >> 24) & 0xff,
      ];
      header.addAll(pcm.toList());

      // Create in-memory WAV data
      final wavData = Uint8List.fromList(header);

      if (_wakeWordDetector == null) {
        await _createDetector();
        return;
      }

      final detected = await _wakeWordDetector!.processAudioData(wavData);

      if (detected && onWakeWordDetected != null) {
        onWakeWordDetected!();
      }
    } catch (e) {
      debugPrint("Error processing wake word: $e");
    }
  }

  Future<void> addChunk(int seq, List<int> data) async {
    await m.acquire();
    if (seq == 255) {
      seqAdd += 255;
    }
    _chunks[seqAdd + seq] = data;
    m.release();

    if (detectWakeWord && _processPCMTicker == null) {
      // Check if wake word detection is enabled in settings
      final wakeWordEnabled = await WakeWordSettings.isEnabled();
      if (!wakeWordEnabled) {
        return;
      }

      // call _handleWakeWord every second
      _processPCMTicker = Timer.periodic(Duration(seconds: 1), (timer) {
        if (!isRecording || !detectWakeWord) {
          timer.cancel();
          _processPCMTicker = null;
          return;
        }
        _handleWakeWord();
      });
    }
  }

  List<int> getAllData() {
    List<int> complete = [];
    final keys = _chunks.keys.toList()..sort();

    for (int key in keys) {
      complete.addAll(_chunks[key]!);
    }
    return complete;
  }

  Future<List<int>> getAllDataAndReset() async {
    await m.acquire();
    final data = getAllData();
    reset(skipWakeWordCheck: true);
    m.release();

    return data;
  }

  void reset({bool skipWakeWordCheck = false}) {
    _chunks.clear();
    seqAdd = 0;
    if (!skipWakeWordCheck) {
      _processPCMTicker?.cancel();
      _processPCMTicker = null;

      _wakeWordDetector?.dispose();
      _wakeWordDetector = null;
    }
  }
}
