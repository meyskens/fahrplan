import 'dart:async';
import 'dart:typed_data';

import 'package:fahrplan/services/bluetooth_manager.dart';
import 'package:fahrplan/services/bluetooth_reciever.dart';
import 'package:fahrplan/services/llm_service.dart';
import 'package:fahrplan/services/whisper.dart';
import 'package:fahrplan/utils/lc3.dart';
import 'package:fahrplan/voice/module.dart';
import 'package:fahrplan/voice/modules/checklist.dart';
import 'package:fahrplan/voice/modules/music.dart';
import 'package:fahrplan/voice/modules/stop.dart';
import 'package:fahrplan/voice/modules/waypoint.dart';
import 'package:fahrplan/voice/modules/webview.dart';
import 'package:flutter/foundation.dart';
import 'package:fuzzywuzzy/fuzzywuzzy.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    WebView(),
    Waypoint(),
    Stop(),
    Music(),
  ];

  final bt = BluetoothManager();
  StreamController<Uint8List>? voiceData;
  StreamController<String>? textStream;
  Timer? fetchVoiceTimer;

  Future<void> startVoiceControl() async {
    try {
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

      String text = "How may I assist you?\n";
      for (VoiceModule module in modules) {
        for (VoiceCommand command in module.commands) {
          text += "- [${module.name}] ${command.command}\n";
        }
      }
      bt.sendText(text, clearOnComplete: false, delay: Duration(seconds: 3));

      //await Future.delayed(const Duration(seconds: 1));

      // Start live transcription
      final whisperService = await WhisperService.service();
      whisperService.transcribeLive(voiceData!.stream, textStream!,
          finalOnly: true);
      // Listen to transcription stream
      String lastTranscription = "";

      Timer? voiceTimer;

      await for (String transcription in textStream!.stream) {
        if (!isListening) break;
        debugPrint('Transcription: $transcription');
        lastTranscription = _prepareTranscript(transcription);

        voiceTimer?.cancel();

        voiceTimer = Timer(Duration(milliseconds: 1300), () async {
          final matchedCommand = await _findBestCommandAsync(lastTranscription);
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
    final matchedCommand = await _findBestCommandAsync(transcription);
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

          if (maxScore > 60) {
            if (bestMatch == null ||
                maxScore > bestMatch.score ||
                (maxScore == bestMatch.score &&
                    phrase.length > bestMatch.phrase.length)) {
              bestMatch = CommandMatch(
                  command: command, phrase: phrase, score: maxScore);
            }
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

  Future<VoiceCommand?> _findBestCommandAsync(String transcription) async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString('voice_command_mode') ?? 'fuzzy';

    if (mode == 'llm') {
      // Build list of all available commands with their trigger phrases
      final commandMap = <String, VoiceCommand>{};
      for (VoiceModule module in modules) {
        for (VoiceCommand command in module.commands) {
          commandMap[command.command] = command;
        }
      }

      final availableCommands = commandMap.keys.toList();
      final matchedCommand =
          await LLMService.matchCommand(transcription, availableCommands);

      if (matchedCommand != null && commandMap.containsKey(matchedCommand)) {
        debugPrint('LLM matched: $matchedCommand');
        return commandMap[matchedCommand];
      } else {
        debugPrint('LLM found no match, falling back to fuzzy matching');
        // Fall back to fuzzy matching if LLM fails
        return _findBestCommand(transcription);
      }
    } else {
      // Use fuzzy matching
      return _findBestCommand(transcription);
    }
  }

  static Future<int> findBestMatch(
      String transcription, List<String> availableCommands) async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString('voice_command_mode') ?? 'fuzzy';

    if (mode == 'llm') {
      final matchedCommand =
          await LLMService.matchCommand(transcription, availableCommands);

      if (matchedCommand != null &&
          availableCommands.contains(matchedCommand)) {
        debugPrint('LLM matched: $matchedCommand');
        return availableCommands.indexOf(matchedCommand);
      } else {
        debugPrint('LLM found no match, falling back to fuzzy matching');
        // Fall back to fuzzy matching if LLM fails
        return _findBestMatch(transcription, availableCommands);
      }
    } else {
      // Use fuzzy matching
      return _findBestMatch(transcription, availableCommands);
    }
  }

  static int _findBestMatch(
      String transcription, List<String> availableCommands) {
    final cleanTranscription = _prepareTranscript(transcription);

    String? bestMatch;
    int bestScore = 0;

    for (String phrase in availableCommands) {
      final cleanPhrase = phrase.toLowerCase();

      // Use multiple fuzzywuzzy algorithms and take the highest score
      final ratioScore = ratio(cleanTranscription, cleanPhrase);
      final partialScore = partialRatio(cleanTranscription, cleanPhrase);
      final tokenSortScore = tokenSortRatio(cleanTranscription, cleanPhrase);
      final tokenSetScore = tokenSetRatio(cleanTranscription, cleanPhrase);

      // Take the highest score from all algorithms
      final maxScore = [ratioScore, partialScore, tokenSortScore, tokenSetScore]
          .reduce((a, b) => a > b ? a : b);

      if (maxScore > 60) {
        if (bestMatch == null ||
            maxScore > bestScore ||
            (maxScore == bestScore && phrase.length > bestMatch.length)) {
          bestMatch = phrase;
          bestScore = maxScore;
        }
      }
    }

    if (bestMatch != null) {
      debugPrint(
          'Best fuzzy match found for $transcription: "$bestMatch" with score: $bestScore');
    } else {
      debugPrint('No suitable command match found for: "$cleanTranscription"');
    }

    return availableCommands.indexOf(bestMatch ?? "");
  }

  static String _prepareTranscript(String transcription) {
    transcription = transcription.replaceAll(RegExp(r'\[.*?\]'), '');
    transcription = transcription.replaceAll(RegExp(r' {2,}'), ' ');
    return transcription.toLowerCase().trim();
  }
}
