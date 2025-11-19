import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fahrplan/services/bluetooth_reciever.dart';
import 'package:fahrplan/utils/lc3.dart';
import 'package:flutter/material.dart';
import 'package:fahrplan/services/bluetooth_manager.dart';
import 'package:fahrplan/models/g1/translate.dart';
import 'package:flutter_lame/flutter_lame.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class MoodAnalysisScreen extends StatefulWidget {
  const MoodAnalysisScreen({super.key});

  @override
  State<MoodAnalysisScreen> createState() => _MoodAnalysisScreenState();
}

class _MoodAnalysisScreenState extends State<MoodAnalysisScreen> {
  final BluetoothManager bluetoothManager = BluetoothManager();
  final TextEditingController _analysisController = TextEditingController();
  Timer? fetchVoiceTimer;
  Timer? analysisTimer;
  Translate? tr;

  StreamController<Uint8List>? voiceData;
  bool isRecording = false;
  List<int> audioBuffer = [];
  final int sampleRate = 16000; // 16kHz sample rate
  final int bufferDurationSeconds = 30;
  final int analysisDurationSeconds = 15;
  bool isAnalyzing = false;

  void _startRecording() async {
    if (!bluetoothManager.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Glasses are not connected')),
      );
      return;
    }

    // Initialize translate for displaying on glasses
    tr = Translate(
        fromLanguage: TranslateLanguages.ENGLISH,
        toLanguage: TranslateLanguages.ENGLISH);
    await bluetoothManager.sendCommandToGlasses(tr!.buildSetupCommand());
    await bluetoothManager.rightGlass!
        .sendData(tr!.buildRightGlassStartCommand());
    for (var cmd in tr!.buildInitalScreenLoad()) {
      await bluetoothManager.sendCommandToGlasses(cmd);
    }
    await Future.delayed(const Duration(milliseconds: 200));

    setState(() {
      isRecording = true;
      audioBuffer.clear();
      _analysisController.text = 'Recording and analyzing...';
    });

    await bluetoothManager.setMicrophone(true);

    final btr = BluetoothReciever();
    btr.voiceCollectorAI.isRecording = true;

    // Timer to fetch voice data periodically
    fetchVoiceTimer = Timer.periodic(Duration(milliseconds: 200), (_) async {
      final lc3Data = await btr.voiceCollectorAI.getAllDataAndReset();
      final pcm = await LC3.decodeLC3(Uint8List.fromList(lc3Data));
      if (pcm.isNotEmpty) {
        audioBuffer.addAll(pcm);

        // Keep only the last 30 seconds of audio (16kHz * 2 bytes per sample * 30 seconds)
        final maxBufferSize = sampleRate * 2 * bufferDurationSeconds;
        if (audioBuffer.length > maxBufferSize) {
          audioBuffer = audioBuffer.sublist(audioBuffer.length - maxBufferSize);
        }
      }
    });

    // Timer to perform analysis every 15 seconds
    analysisTimer =
        Timer.periodic(Duration(seconds: analysisDurationSeconds), (_) async {
      if (!isAnalyzing && audioBuffer.isNotEmpty) {
        _performAnalysis();
      }
    });
  }

  void _stopRecording() async {
    await bluetoothManager.setMicrophone(false);
    fetchVoiceTimer?.cancel();
    analysisTimer?.cancel();

    final btr = BluetoothReciever();
    btr.voiceCollectorAI.isRecording = false;
    btr.voiceCollectorAI.reset();

    setState(() {
      isRecording = false;
    });
  }

  void _performAnalysis() async {
    if (audioBuffer.isEmpty) return;

    setState(() {
      isAnalyzing = true;
    });

    try {
      // Create a copy of the current buffer for analysis
      final bufferCopy = Uint8List.fromList(List.from(audioBuffer));

      final Directory tempDir = await getTemporaryDirectory();
      final String mp3Path =
          '${tempDir.path}/mood_audio_${DateTime.now().millisecondsSinceEpoch}.mp3';

      final File f = File(mp3Path);
      final IOSink sink = f.openWrite();
      final LameMp3Encoder encoder =
          LameMp3Encoder(sampleRate: 16000, numChannels: 1);

      // Get samples from file or from microphone.
      // Convert Uint8List PCM data to Int16List
      final int16Data = Int16List.view(bufferCopy.buffer);

      final mp3Frame = await encoder.encode(leftChannel: int16Data);
      sink.add(mp3Frame);

      final lastMp3Frame = await encoder.flush();
      sink.add(lastMp3Frame);
      await sink.close();

      // Convert WAV to MP3

      // Send MP3 audio to voxtral model for mood analysis
      final moodAnalysis = await _analyzeAudioWithVoxtral(mp3Path);

      // Clean up temp files
      try {
        await File(mp3Path).delete();
      } catch (e) {
        debugPrint('Failed to delete temp files: $e');
      }

      if (mounted) {
        final analysisText = moodAnalysis ??
            'Unable to analyze mood. Please check LLM configuration.';

        setState(() {
          _analysisController.text = analysisText;
          isAnalyzing = false;
        });

        // Send to glasses - split into chunks if needed
        await _sendToGlasses(analysisText);
      }
    } catch (e) {
      if (mounted) {
        final errorText = 'Error: ${e.toString()}';
        setState(() {
          _analysisController.text = errorText;
          isAnalyzing = false;
        });

        // Send error to glasses too
        await _sendToGlasses(errorText);
      }
    }
  }

  Future<void> _sendToGlasses(String text) async {
    if (tr == null || !bluetoothManager.isConnected) return;

    // Split text into chunks of 220 characters max (glasses display limit)
    final chunks = <String>[];
    for (int i = 0; i < text.length; i += 220) {
      final end = (i + 220 < text.length) ? i + 220 : text.length;
      chunks.add(text.substring(i, end));
    }

    // Send each chunk to glasses
    for (final chunk in chunks) {
      await bluetoothManager
          .sendCommandToGlasses(tr!.buildTranslatedCommand(chunk));
      await bluetoothManager
          .sendCommandToGlasses(tr!.buildOriginalCommand(chunk));
      // Small delay between chunks
      if (chunks.length > 1) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
  }

  Future<String?> _analyzeAudioWithVoxtral(String audioFilePath) async {
    try {
      final config = await _getLLMConfig();
      if (config == null) return null;

      final endpoint = config['apiUrl']!.endsWith('/chat/completions')
          ? config['apiUrl']!
          : '${config['apiUrl']}/chat/completions';

      // Read the audio file
      final audioBytes = await File(audioFilePath).readAsBytes();
      final audioBase64 = base64Encode(audioBytes);

      const systemPrompt =
          '''You are an empathetic mood analyzer for an autistic individual. 
Analyze the emotional tone and sentiment of the user's speech from the audio.
Provide a brief, compassionate summary of heard emotions and mood in 3 words. Only reply these 3 words, no emojis, no markup.''';

      final response = await http
          .post(
            Uri.parse(endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${config['apiKey']}',
            },
            body: jsonEncode({
              'model': 'voxtral-small-24b-2507',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': systemPrompt},
                    {
                      'type': 'input_audio',
                      'input_audio': {'data': audioBase64, 'format': 'mp3'}
                    }
                  ]
                },
              ],
              'temperature': 0.3,
              'max_tokens': 1000,
            }),
          )
          .timeout(Duration(seconds: 60));

      if (response.statusCode != 200) {
        debugPrint(
            'Voxtral API error: ${response.statusCode} - ${response.body}');
        return 'API Error: ${response.statusCode}';
      }

      final jsonResponse = jsonDecode(response.body);
      if (jsonResponse['choices'] != null &&
          jsonResponse['choices'].isNotEmpty) {
        final message = jsonResponse['choices'][0]['message'];
        if (message != null) {
          final content = message['content'];
          if (content is String) {
            return content.trim();
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error analyzing audio with Voxtral: $e');
      return 'Error: ${e.toString()}';
    }
  }

  Future<Map<String, String>?> _getLLMConfig() async {
    // Reuse the LLM configuration from shared preferences
    final prefs = await SharedPreferences.getInstance();
    final apiUrl = prefs.getString('llm_api_url');
    final apiKey = prefs.getString('llm_api_key');

    if (apiUrl == null || apiUrl.isEmpty || apiKey == null || apiKey.isEmpty) {
      return null;
    }

    return {'apiUrl': apiUrl, 'apiKey': apiKey};
  }

  @override
  void dispose() {
    fetchVoiceTimer?.cancel();
    analysisTimer?.cancel();
    _analysisController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mood Analysis'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (isRecording)
              Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  Text(
                    isAnalyzing ? 'Analyzing...' : 'Recording...',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            if (!isRecording)
              ElevatedButton(
                onPressed: _startRecording,
                child: const Text('Start Continuous Mood Analysis'),
              ),
            if (isRecording)
              ElevatedButton(
                onPressed: _stopRecording,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                child: const Text('Stop Recording'),
              ),
            const SizedBox(height: 20),
            Expanded(
              child: TextField(
                controller: _analysisController,
                decoration: const InputDecoration(
                  labelText: 'Mood Analysis',
                  border: OutlineInputBorder(),
                ),
                readOnly: true,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
