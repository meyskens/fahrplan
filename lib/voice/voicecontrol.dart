import 'dart:async';
import 'dart:typed_data';

import 'package:fahrplan/services/bluetooth_manager.dart';
import 'package:fahrplan/services/bluetooth_reciever.dart';
import 'package:fahrplan/services/whisper.dart';
import 'package:fahrplan/utils/lc3.dart';
import 'package:fahrplan/voice/module.dart';
import 'package:fahrplan/voice/modules/checklist.dart';
import 'package:fahrplan/voice/modules/music.dart';
import 'package:flutter/foundation.dart';
import 'package:fuzzywuzzy/fuzzywuzzy.dart';

class CommandMatch {
  final VoiceCommand command;
  final String phrase;
  final int score;

  CommandMatch(
      {required this.command, required this.phrase, required this.score});
}

class Voicecontrol {
  static final Voicecontrol _instance = Voicecontrol._internal();
  factory Voicecontrol() {
    return _instance;
  }

  Voicecontrol._internal();

  List<VoiceModule> modules = [
    Checklist(),
    Music(),
  ];

  final bt = BluetoothManager();
  StreamController<Uint8List>? voiceData;
  StreamController<String>? textStream;
  Timer? fetchVoiceTimer;

  Future<void> startVoiceControl() async {
    try {
      String text = "How may I assist you?\n";
      for (VoiceModule module in modules) {
        for (VoiceCommand command in module.commands) {
          text += "- [${module.name}] ${command.command}\n";
        }
      }
      bt.sendText(text, clearOnComplete: false, delay: Duration(seconds: 3));

      await Future.delayed(const Duration(seconds: 1));

      // Start voice data collection
      final btr = BluetoothReciever.singleton;
      btr.voiceCollectorAI.isRecording = true;

      await bt.setMicrophone(true);

      // Initialize stream controllers
      voiceData = StreamController<Uint8List>();
      textStream = StreamController<String>();

      // Set up periodic timer to collect and decode LC3 data
      fetchVoiceTimer = Timer.periodic(Duration(milliseconds: 200), (_) async {
        if (!btr.voiceCollectorAI.isRecording) return;
        final lc3Data = await btr.voiceCollectorAI.getAllDataAndReset();
        final pcm = await LC3.decodeLC3(Uint8List.fromList(lc3Data));
        if (pcm.isNotEmpty) {
          voiceData?.add(pcm);
        }
      });

      // Set up timeout for maximum listening time (30 seconds)
      Timer? timeoutTimer;
      bool isListening = true;
      const int maxListeningMs = 10000; // 10 seconds max

      timeoutTimer = Timer(Duration(milliseconds: maxListeningMs), () async {
        if (isListening) {
          debugPrint('Voice control timed out after $maxListeningMs ms');
          isListening = false;
          await _stopListening();
          await bt.clearScreen();
        }
      });

      // Start live transcription
      final whisperService = await WhisperService.service();
      whisperService.transcribeLive(voiceData!.stream, textStream!);
      // Listen to transcription stream
      String lastTranscription = "";

      Timer? voiceTimer;

      await for (String transcription in textStream!.stream) {
        if (!isListening) break;
        debugPrint('Transcription: $transcription');
        lastTranscription = _prepareTranscript(transcription);

        voiceTimer?.cancel();

        voiceTimer = Timer(Duration(milliseconds: 1300), () async {
          final matchedCommand = _findBestCommand(lastTranscription);
          if (matchedCommand != null) {
            isListening = false;
            timeoutTimer?.cancel();

            await _stopListening();
            matchedCommand.execute(lastTranscription);
            return;
          }
        });
      }

      // Clean up if we exit the stream normally
      if (isListening) {
        timeoutTimer.cancel();
        await _stopListening();
        await bt.sendText("Voice control ended.");
      }
    } catch (e) {
      debugPrint('Error in voice control: $e');
      await _stopListening();
      await bt.sendText("Voice control error occurred.");
    }
  }

  Future<void> launch(String transcription) async {
    final matchedCommand = _findBestCommand(transcription);
    if (matchedCommand == null) {
      await bt.sendText('Command "$transcription" not recognised');
    }

    matchedCommand!.execute(transcription);
    return;
  }

  Future<void> _stopListening() async {
    final btr = BluetoothReciever.singleton;
    btr.voiceCollectorAI.isRecording = false;
    btr.voiceCollectorAI.reset();
    await bt.setMicrophone(false);

    // Clean up stream controllers and timer
    fetchVoiceTimer?.cancel();
    voiceData?.close();
    textStream?.close();

    fetchVoiceTimer = null;
    voiceData = null;
    textStream = null;
  }

  VoiceCommand? _findBestCommand(String transcription) {
    final cleanTranscription = _prepareTranscript(transcription);

    CommandMatch? bestMatch;

    for (VoiceModule module in modules) {
      for (VoiceCommand command in module.commands) {
        for (String phrase in command.triggerPhrases) {
          final cleanPhrase = phrase.toLowerCase();

          // Use multiple fuzzywuzzy algorithms and take the highest score
          final ratioScore = ratio(cleanTranscription, cleanPhrase);
          final partialScore = partialRatio(cleanTranscription, cleanPhrase);
          final tokenSortScore =
              tokenSortRatio(cleanTranscription, cleanPhrase);
          final tokenSetScore = tokenSetRatio(cleanTranscription, cleanPhrase);

          // Take the highest score from all algorithms
          final maxScore = [
            ratioScore,
            partialScore,
            tokenSortScore,
            tokenSetScore
          ].reduce((a, b) => a > b ? a : b);

          if (maxScore > 60 &&
              (bestMatch == null || maxScore > bestMatch.score)) {
            bestMatch =
                CommandMatch(command: command, phrase: phrase, score: maxScore);
          }
        }
      }
    }

    if (bestMatch != null) {
      debugPrint(
          'Best fuzzy match found for $transcription: "${bestMatch.phrase}" with score: ${bestMatch.score}');
    } else {
      debugPrint('No suitable command match found for: "$cleanTranscription"');
    }

    return bestMatch?.command;
  }

  String _prepareTranscript(String transcription) {
    transcription = transcription.replaceAll(RegExp(r'\[.*?\]'), '');
    transcription = transcription.replaceAll(RegExp(r' {2,}'), ' ');
    return transcription.toLowerCase().trim();
  }
}
