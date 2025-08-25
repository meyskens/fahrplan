import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:dart_openai/dart_openai.dart';
import 'package:fahrplan/models/fahrplan/whispermodel.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:whisper_ggml/whisper_ggml.dart';
import 'package:web_socket_client/web_socket_client.dart';

abstract class WhisperService {
  static Future<WhisperService> service() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString('whisper_mode') ?? 'local';
    if (mode == "remote") {
      return WhisperRemoteService();
    }

    return WhisperLocalService();
  }

  Future<String> transcribe(Uint8List voiceData);
  Future<void> transcribeLive(
      Stream<Uint8List> voiceData, StreamController<String> out) async {}
}

class WhisperLocalService implements WhisperService {
  @override
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

    final whisper = WhisperController();
    final model = FahrplanWhisperModel(prefs.getString('whisper_model') ?? '');

    final result = await whisper.transcribe(
      model: model.model,
      audioPath: wavPath,
      lang: prefs.getString('whisper_language') ?? 'en',
    );

    // delete wav file
    await File(wavPath).delete();

    return result!.transcription.text;
  }

  Future<void> transcribeLive(
      Stream<Uint8List> voiceData, StreamController<String> out) async {
    final int sampleRate = 16000;
    final int bytesPerSample = 2; // 16-bit audio
    final int chunkDurationSeconds = 4;
    final int chunkSizeBytes =
        sampleRate * bytesPerSample * chunkDurationSeconds;

    // VAD parameters
    final double silenceThresholdRms =
        0.01; // RMS threshold for silence detection
    final int chunkSilenceDurationMs =
        500; // 500 milliseconds of silence to trigger chunk
    final int silenceSamples =
        (sampleRate * chunkSilenceDurationMs / 1000).round();

    List<int> audioBuffer = [];
    int silenceCounter = 0;
    bool hasVoiceActivity = false;
    String accumulatedTranscription = '';

    SharedPreferences prefs = await SharedPreferences.getInstance();
    final whisper = WhisperController();
    final model = FahrplanWhisperModel(prefs.getString('whisper_model') ?? '');
    final language = prefs.getString('whisper_language') ?? 'en';

    await for (final data in voiceData) {
      audioBuffer.addAll(data);

      // Simple VAD: calculate RMS energy of the current chunk
      if (data.length >= bytesPerSample) {
        double rms = _calculateRMS(data);

        if (rms > silenceThresholdRms) {
          // Voice activity detected
          hasVoiceActivity = true;
          silenceCounter = 0;
        } else {
          // Silence detected
          silenceCounter += data.length ~/ bytesPerSample;
        }
      }

      // Check if we should process the current buffer
      bool shouldProcess = false;

      // Process if buffer is getting too large
      if (audioBuffer.length >= chunkSizeBytes) {
        shouldProcess = true;
      }
      // Process if we detected voice activity followed by silence
      else if (hasVoiceActivity && silenceCounter >= silenceSamples) {
        shouldProcess = true;
      }

      if (shouldProcess && audioBuffer.isNotEmpty) {
        // Only transcribe if we detected voice activity
        if (hasVoiceActivity) {
          try {
            print('Transcribing chunk of size: ${audioBuffer.length}');
            final transcription = await _transcribeChunk(
              Uint8List.fromList(audioBuffer),
              whisper,
              model,
              language,
            );

            if (transcription.isNotEmpty) {
              // Append to accumulated transcription
              accumulatedTranscription += ' ' + transcription;

              // Cut off at 500 characters from the beginning, ensuring words are not cut in half
              if (accumulatedTranscription.length > 280) {
                String trimmed = accumulatedTranscription
                    .substring(accumulatedTranscription.length - 280);

                // Find the first space to avoid cutting words in half
                int firstSpaceIndex = trimmed.indexOf(' ');
                if (firstSpaceIndex != -1) {
                  accumulatedTranscription =
                      trimmed.substring(firstSpaceIndex + 1);
                } else {
                  accumulatedTranscription = trimmed;
                }
              }

              out.add(accumulatedTranscription);
            }
          } catch (e) {
            debugPrint('Error transcribing chunk: $e');
          }
        } else {
          print('Skipping transcription - no voice activity detected in chunk');
        }

        // Reset buffer and VAD state
        audioBuffer.clear();
        silenceCounter = 0;
        hasVoiceActivity = false;
      }
    }

    // Process any remaining audio in the buffer
    if (audioBuffer.isNotEmpty && hasVoiceActivity) {
      try {
        print('Transcribing final chunk of size: ${audioBuffer.length}');
        final transcription = await _transcribeChunk(
          Uint8List.fromList(audioBuffer),
          whisper,
          model,
          language,
        );

        if (transcription.isNotEmpty) {
          // Append to accumulated transcription
          accumulatedTranscription += ' ' + transcription;

          // Cut off at 500 characters from the beginning, ensuring words are not cut in half
          if (accumulatedTranscription.length > 500) {
            String trimmed = accumulatedTranscription
                .substring(accumulatedTranscription.length - 500);

            // Find the first space to avoid cutting words in half
            int firstSpaceIndex = trimmed.indexOf(' ');
            if (firstSpaceIndex != -1) {
              accumulatedTranscription = trimmed.substring(firstSpaceIndex + 1);
            } else {
              accumulatedTranscription = trimmed;
            }
          }

          out.add(accumulatedTranscription);
        }
      } catch (e) {
        debugPrint('Error transcribing final chunk: $e');
      }
    } else if (audioBuffer.isNotEmpty) {
      print('Skipping final chunk transcription - no voice activity detected');
    }
  }

  double _calculateRMS(Uint8List audioData) {
    if (audioData.length < 2) return 0.0;

    double sum = 0.0;
    int sampleCount = 0;

    // Process 16-bit samples (2 bytes each)
    for (int i = 0; i < audioData.length - 1; i += 2) {
      // Convert bytes to 16-bit signed integer
      int sample = (audioData[i + 1] << 8) | audioData[i];
      if (sample > 32767) sample -= 65536; // Convert to signed

      sum += sample * sample;
      sampleCount++;
    }

    if (sampleCount == 0) return 0.0;
    return math.sqrt(sum / sampleCount) / 32768.0; // Normalize to 0-1 range
  }

  Future<String> _transcribeChunk(
    Uint8List voiceData,
    WhisperController whisper,
    FahrplanWhisperModel model,
    String language,
  ) async {
    final Directory documentDirectory =
        await getApplicationDocumentsDirectory();
    final String wavPath = '${documentDirectory.path}/${Uuid().v4()}.wav';

    try {
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

      final result = await whisper.transcribe(
        model: model.model,
        audioPath: wavPath,
        lang: language,
      );

      return result?.transcription.text ?? '';
    } catch (e) {
      debugPrint('Error in _transcribeChunk: $e');
      return '';
    } finally {
      // Clean up temp file
      try {
        await File(wavPath).delete();
      } catch (e) {
        debugPrint('Error deleting temp file: $e');
      }
    }
  }
}

class WhisperRemoteService implements WhisperService {
  Future<String?> getBaseURL() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('whisper_api_url');
  }

  Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('whisper_api_key');
  }

  Future<String?> getModel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('whisper_remote_model');
  }

  Future<String?> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('whisper_language');
  }

  Future<void> init() async {
    final url = await getBaseURL();
    if (url == null) {
      throw Exception("no Whisper Remote URL set");
    }
    debugPrint('Initializing Whisper Remote Service with URL: $url');
    OpenAI.baseUrl = url;
    OpenAI.apiKey = await getApiKey() ?? '';
  }

  @override
  Future<String> transcribe(Uint8List voiceData) async {
    debugPrint('Transcribing voice data');
    await init();
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

    final audioFile = File(wavPath);
    await audioFile.writeAsBytes(Uint8List.fromList(header));

    OpenAIAudioModel transcription =
        await OpenAI.instance.audio.createTranscription(
      file: audioFile,
      model: await getModel() ?? '',
      responseFormat: OpenAIAudioResponseFormat.json,
      language: await getLanguage(),
    );

    // delete wav file
    await File(wavPath).delete();

    var text = transcription.text;

    return text;
  }

  Future<void> transcribeLive(
      Stream<Uint8List> voiceData, StreamController<String> out) async {
    await init();
    final url = (await getBaseURL())!.replaceFirst("http", "ws");
    final model = await getModel();
    final socket =
        WebSocket(Uri.parse('$url/v1/audio/transcriptions?model=$model'));

    // Add wav header
    final int sampleRate = 16000;
    final int numChannels = 1;
    final int byteRate = sampleRate * numChannels * 2;
    final int blockAlign = numChannels * 2;
    final int bitsPerSample = 16;
    final int dataSize = 99999999999999999; // set as high as well.. we can
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

    socket.send(header);

    // Listen to messages from the server.
    socket.messages.listen((message) {
      final resp = LiveResponse.fromJson(jsonDecode(message));
      out.add(resp.text ?? '');
    });

    await for (final data in voiceData) {
      socket.send(data);
    }

    socket.close();
  }
}

class LiveResponse {
  String? text;

  LiveResponse({this.text});

  LiveResponse.fromJson(Map<String, dynamic> json) {
    text = json['text'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['text'] = text;
    return data;
  }
}
