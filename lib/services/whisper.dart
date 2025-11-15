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
      print("Using remote whisper service");
      return WhisperRemoteService();
    }
    if (mode == "azure") {
      print("Using Azure Speech service");
      return WhisperAzureSpeechService();
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

  @override
  Future<void> transcribeLive(
      Stream<Uint8List> voiceData, StreamController<String> out) async {
    final int sampleRate = 16000;
    final int bytesPerSample = 2; // 16-bit audio
    final int chunkDurationSeconds = 5; // Increased to capture more context
    final int chunkSizeBytes =
        sampleRate * bytesPerSample * chunkDurationSeconds;

    // Overlap buffer: keep last 1.5 seconds for context
    final int overlapDurationSeconds = 2;
    final int overlapSizeBytes =
        sampleRate * bytesPerSample * overlapDurationSeconds;

    // VAD parameters - tuned for better sentence detection
    final double silenceThresholdRms =
        0.015; // Slightly higher to avoid noise triggering
    final int chunkSilenceDurationMs =
        800; // Longer silence to wait for natural pauses
    final int silenceSamples =
        (sampleRate * chunkSilenceDurationMs / 1000).round();

    List<int> audioBuffer = [];
    List<int> overlapBuffer = []; // Store audio for overlap
    int silenceCounter = 0;
    bool hasVoiceActivity = false;
    String accumulatedTranscription = '';
    String lastPartialSentence = ''; // Track incomplete sentences

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

            // Combine overlap buffer with current buffer for context
            List<int> bufferWithOverlap = [...overlapBuffer, ...audioBuffer];

            final transcription = await _transcribeChunk(
              Uint8List.fromList(bufferWithOverlap),
              whisper,
              model,
              language,
            );

            if (transcription.isNotEmpty) {
              // Smart merge: detect if we have overlapping content
              String newText = _mergeTranscriptions(
                accumulatedTranscription,
                lastPartialSentence,
                transcription,
              );

              accumulatedTranscription = newText;

              // Extract last partial sentence for next overlap
              lastPartialSentence = _extractLastPartialSentence(transcription);

              // Keep reasonable length, trim at sentence boundaries
              if (accumulatedTranscription.length > 400) {
                accumulatedTranscription = _trimAtSentenceBoundary(
                  accumulatedTranscription,
                  300,
                );
              }

              out.add(accumulatedTranscription);
            }

            // Save overlap buffer for next chunk
            if (audioBuffer.length > overlapSizeBytes) {
              overlapBuffer =
                  audioBuffer.sublist(audioBuffer.length - overlapSizeBytes);
            } else {
              overlapBuffer = List.from(audioBuffer);
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

        List<int> bufferWithOverlap = [...overlapBuffer, ...audioBuffer];

        final transcription = await _transcribeChunk(
          Uint8List.fromList(bufferWithOverlap),
          whisper,
          model,
          language,
        );

        if (transcription.isNotEmpty) {
          String newText = _mergeTranscriptions(
            accumulatedTranscription,
            lastPartialSentence,
            transcription,
          );

          accumulatedTranscription = newText;

          if (accumulatedTranscription.length > 500) {
            accumulatedTranscription = _trimAtSentenceBoundary(
              accumulatedTranscription,
              400,
            );
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

  /// Merges new transcription with accumulated text, handling overlaps
  String _mergeTranscriptions(
    String accumulated,
    String lastPartial,
    String newText,
  ) {
    // Clean up the new text
    String cleanNew = newText.trim();

    if (accumulated.isEmpty) {
      return cleanNew;
    }

    // Try to find overlap using the last partial sentence
    if (lastPartial.isNotEmpty) {
      // Find where the overlap starts in the new transcription
      String lastPartialClean = lastPartial.trim().toLowerCase();
      String newTextLower = cleanNew.toLowerCase();

      // Check for overlap at the start of new text
      if (newTextLower.startsWith(lastPartialClean)) {
        // Direct overlap - just append the new part
        return accumulated +
            ' ' +
            cleanNew.substring(lastPartial.length).trim();
      }

      // Try to find partial overlap (at least 3 words)
      List<String> lastWords = lastPartialClean.split(' ');
      for (int i = math.min(3, lastWords.length); i <= lastWords.length; i++) {
        String overlap = lastWords.sublist(lastWords.length - i).join(' ');
        if (newTextLower.startsWith(overlap)) {
          // Found overlap - remove duplicate part from accumulated
          int cutPoint = accumulated.toLowerCase().lastIndexOf(overlap);
          if (cutPoint > 0) {
            return accumulated.substring(0, cutPoint).trim() + ' ' + cleanNew;
          }
        }
      }
    }

    // No overlap found - check if we should append or replace last sentence
    if (_endsWithCompleteSentence(accumulated)) {
      // Previous ends with complete sentence - safe to append
      return accumulated + ' ' + cleanNew;
    } else {
      // Previous might be incomplete - try to merge intelligently
      // Remove last incomplete sentence and add new text
      String trimmed = _removeLastIncompleteSentence(accumulated);
      return trimmed + ' ' + cleanNew;
    }
  }

  /// Extracts the last incomplete sentence from text
  String _extractLastPartialSentence(String text) {
    if (text.isEmpty) return '';

    // Find last sentence-ending punctuation
    final sentenceEnders = RegExp(r'[.!?]\s');
    final matches = sentenceEnders.allMatches(text);

    if (matches.isEmpty) {
      return text.trim();
    }

    final lastMatch = matches.last;
    return text.substring(lastMatch.end).trim();
  }

  /// Checks if text ends with complete sentence
  bool _endsWithCompleteSentence(String text) {
    if (text.isEmpty) return false;
    text = text.trimRight();
    return text.endsWith('.') || text.endsWith('!') || text.endsWith('?');
  }

  /// Removes last incomplete sentence from text
  String _removeLastIncompleteSentence(String text) {
    if (text.isEmpty) return '';

    final sentenceEnders = RegExp(r'[.!?]\s');
    final matches = sentenceEnders.allMatches(text);

    if (matches.isEmpty) {
      return ''; // Entire text is one incomplete sentence
    }

    final lastMatch = matches.last;
    return text.substring(0, lastMatch.end).trim();
  }

  /// Trims text to target length at sentence boundary
  String _trimAtSentenceBoundary(String text, int targetLength) {
    if (text.length <= targetLength) {
      return text;
    }

    // Get substring around target length
    String trimmed = text.substring(text.length - targetLength);

    // Find first sentence boundary (after punctuation)
    final sentenceStarts = RegExp(r'[.!?]\s+\S');
    final match = sentenceStarts.firstMatch(trimmed);

    if (match != null) {
      // Trim to start of sentence after punctuation
      return trimmed.substring(match.start + 2).trim();
    }

    // Fallback: find first word boundary
    int firstSpace = trimmed.indexOf(' ');
    if (firstSpace > 0) {
      return trimmed.substring(firstSpace + 1).trim();
    }

    return trimmed.trim();
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

  Future<bool> getUseWebSocket() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('whisper_use_websocket') ?? true;
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
      //responseFormat: OpenAIAudioResponseFormat.json,
      language: await getLanguage(),
    );

    // delete wav file
    await File(wavPath).delete();

    var text = transcription.text;

    return text;
  }

  @override
  Future<void> transcribeLive(
      Stream<Uint8List> voiceData, StreamController<String> out) async {
    final useWebSocket = await getUseWebSocket();

    if (useWebSocket) {
      await _transcribeLiveWebSocket(voiceData, out);
    } else {
      await _transcribeLiveChunked(voiceData, out);
    }
  }

  Future<void> _transcribeLiveWebSocket(
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

  Future<void> _transcribeLiveChunked(
      Stream<Uint8List> voiceData, StreamController<String> out) async {
    await init();

    final int sampleRate = 16000;
    final int bytesPerSample = 2; // 16-bit audio
    final int chunkDurationSeconds = 5; // Increased to capture more context
    final int chunkSizeBytes =
        sampleRate * bytesPerSample * chunkDurationSeconds;

    // Overlap buffer: keep last 2 seconds for context
    final int overlapDurationSeconds = 2;
    final int overlapSizeBytes =
        sampleRate * bytesPerSample * overlapDurationSeconds;

    // VAD parameters - tuned for better sentence detection
    final double silenceThresholdRms =
        0.015; // Slightly higher to avoid noise triggering
    final int chunkSilenceDurationMs =
        800; // Longer silence to wait for natural pauses
    final int silenceSamples =
        (sampleRate * chunkSilenceDurationMs / 1000).round();

    List<int> audioBuffer = [];
    List<int> overlapBuffer = []; // Store audio for overlap
    int silenceCounter = 0;
    bool hasVoiceActivity = false;
    String accumulatedTranscription = '';
    String lastPartialSentence = ''; // Track incomplete sentences

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

            // Combine overlap buffer with current buffer for context
            List<int> bufferWithOverlap = [...overlapBuffer, ...audioBuffer];

            final transcription = await _transcribeChunkRemote(
              Uint8List.fromList(bufferWithOverlap),
            );

            if (transcription.isNotEmpty) {
              // Smart merge: detect if we have overlapping content
              String newText = _mergeTranscriptions(
                accumulatedTranscription,
                lastPartialSentence,
                transcription,
              );

              accumulatedTranscription = newText;

              // Extract last partial sentence for next overlap
              lastPartialSentence = _extractLastPartialSentence(transcription);

              // Keep reasonable length, trim at sentence boundaries
              if (accumulatedTranscription.length > 400) {
                accumulatedTranscription = _trimAtSentenceBoundary(
                  accumulatedTranscription,
                  300,
                );
              }

              out.add(accumulatedTranscription);
            }

            // Save overlap buffer for next chunk
            if (audioBuffer.length > overlapSizeBytes) {
              overlapBuffer =
                  audioBuffer.sublist(audioBuffer.length - overlapSizeBytes);
            } else {
              overlapBuffer = List.from(audioBuffer);
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

        List<int> bufferWithOverlap = [...overlapBuffer, ...audioBuffer];

        final transcription = await _transcribeChunkRemote(
          Uint8List.fromList(bufferWithOverlap),
        );

        if (transcription.isNotEmpty) {
          String newText = _mergeTranscriptions(
            accumulatedTranscription,
            lastPartialSentence,
            transcription,
          );

          accumulatedTranscription = newText;

          if (accumulatedTranscription.length > 500) {
            accumulatedTranscription = _trimAtSentenceBoundary(
              accumulatedTranscription,
              400,
            );
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

  /// Merges new transcription with accumulated text, handling overlaps
  String _mergeTranscriptions(
    String accumulated,
    String lastPartial,
    String newText,
  ) {
    // Clean up the new text
    String cleanNew = newText.trim();

    if (accumulated.isEmpty) {
      return cleanNew;
    }

    // Try to find overlap using the last partial sentence
    if (lastPartial.isNotEmpty) {
      // Find where the overlap starts in the new transcription
      String lastPartialClean = lastPartial.trim().toLowerCase();
      String newTextLower = cleanNew.toLowerCase();

      // Check for overlap at the start of new text
      if (newTextLower.startsWith(lastPartialClean)) {
        // Direct overlap - just append the new part
        return accumulated +
            ' ' +
            cleanNew.substring(lastPartial.length).trim();
      }

      // Try to find partial overlap (at least 3 words)
      List<String> lastWords = lastPartialClean.split(' ');
      for (int i = math.min(3, lastWords.length); i <= lastWords.length; i++) {
        String overlap = lastWords.sublist(lastWords.length - i).join(' ');
        if (newTextLower.startsWith(overlap)) {
          // Found overlap - remove duplicate part from accumulated
          int cutPoint = accumulated.toLowerCase().lastIndexOf(overlap);
          if (cutPoint > 0) {
            return accumulated.substring(0, cutPoint).trim() + ' ' + cleanNew;
          }
        }
      }
    }

    // No overlap found - check if we should append or replace last sentence
    if (_endsWithCompleteSentence(accumulated)) {
      // Previous ends with complete sentence - safe to append
      return accumulated + ' ' + cleanNew;
    } else {
      // Previous might be incomplete - try to merge intelligently
      // Remove last incomplete sentence and add new text
      String trimmed = _removeLastIncompleteSentence(accumulated);
      return trimmed + ' ' + cleanNew;
    }
  }

  /// Extracts the last incomplete sentence from text
  String _extractLastPartialSentence(String text) {
    if (text.isEmpty) return '';

    // Find last sentence-ending punctuation
    final sentenceEnders = RegExp(r'[.!?]\s');
    final matches = sentenceEnders.allMatches(text);

    if (matches.isEmpty) {
      return text.trim();
    }

    final lastMatch = matches.last;
    return text.substring(lastMatch.end).trim();
  }

  /// Checks if text ends with complete sentence
  bool _endsWithCompleteSentence(String text) {
    if (text.isEmpty) return false;
    text = text.trimRight();
    return text.endsWith('.') || text.endsWith('!') || text.endsWith('?');
  }

  /// Removes last incomplete sentence from text
  String _removeLastIncompleteSentence(String text) {
    if (text.isEmpty) return '';

    final sentenceEnders = RegExp(r'[.!?]\s');
    final matches = sentenceEnders.allMatches(text);

    if (matches.isEmpty) {
      return ''; // Entire text is one incomplete sentence
    }

    final lastMatch = matches.last;
    return text.substring(0, lastMatch.end).trim();
  }

  /// Trims text to target length at sentence boundary
  String _trimAtSentenceBoundary(String text, int targetLength) {
    if (text.length <= targetLength) {
      return text;
    }

    // Get substring around target length
    String trimmed = text.substring(text.length - targetLength);

    // Find first sentence boundary (after punctuation)
    final sentenceStarts = RegExp(r'[.!?]\s+\S');
    final match = sentenceStarts.firstMatch(trimmed);

    if (match != null) {
      // Trim to start of sentence after punctuation
      return trimmed.substring(match.start + 2).trim();
    }

    // Fallback: find first word boundary
    int firstSpace = trimmed.indexOf(' ');
    if (firstSpace > 0) {
      return trimmed.substring(firstSpace + 1).trim();
    }

    return trimmed.trim();
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

  Future<String> _transcribeChunkRemote(Uint8List voiceData) async {
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

      final audioFile = File(wavPath);
      await audioFile.writeAsBytes(Uint8List.fromList(header));

      OpenAIAudioModel transcription =
          await OpenAI.instance.audio.createTranscription(
        file: audioFile,
        model: await getModel() ?? '',
        language: await getLanguage(),
      );

      return transcription.text;
    } catch (e) {
      debugPrint('Error in _transcribeChunkRemote: $e');
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

class WhisperAzureSpeechService implements WhisperService {
  Future<String?> getSubscriptionKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('azure_speech_key');
  }

  Future<String?> getRegion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('azure_speech_region');
  }

  Future<String?> getBridgeServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('azure_bridge_server_url');
  }

  Future<String?> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('whisper_language') ?? 'en-US';
  }

  String _convertLanguageCode(String? lang) {
    // Convert simple language codes to Azure Speech locale codes
    if (lang == null) return 'en-US';

    final Map<String, String> languageMap = {
      'en': 'en-US',
      'es': 'es-ES',
      'fr': 'fr-FR',
      'de': 'de-DE',
      'it': 'it-IT',
      'pt': 'pt-PT',
      'nl': 'nl-NL',
      'ru': 'ru-RU',
      'zh': 'zh-CN',
      'ja': 'ja-JP',
      'ko': 'ko-KR',
      'ar': 'ar-SA',
      'hi': 'hi-IN',
      'bn': 'bn-IN',
      'ur': 'ur-PK',
      'ta': 'ta-IN',
      'te': 'te-IN',
      'mr': 'mr-IN',
      'gu': 'gu-IN',
      'kn': 'kn-IN',
      'ml': 'ml-IN',
      'pa': 'pa-IN',
      'th': 'th-TH',
      'vi': 'vi-VN',
      'tl': 'fil-PH',
      'tr': 'tr-TR',
      'fa': 'fa-IR',
      'he': 'he-IL',
      'sw': 'sw-KE',
    };

    return languageMap[lang] ?? lang;
  }

  @override
  Future<String> transcribe(Uint8List voiceData) async {
    final subscriptionKey = await getSubscriptionKey();
    final region = await getRegion();
    final language = _convertLanguageCode(await getLanguage());

    if (subscriptionKey == null || subscriptionKey.isEmpty) {
      throw Exception("Azure Speech subscription key not set");
    }
    if (region == null || region.isEmpty) {
      throw Exception("Azure Speech region not set");
    }

    debugPrint('Transcribing with Azure Speech Service');
    final Directory documentDirectory =
        await getApplicationDocumentsDirectory();
    final String wavPath = '${documentDirectory.path}/${Uuid().v4()}.wav';

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

    try {
      final url = Uri.parse(
          'https://$region.stt.speech.microsoft.com/speech/recognition/conversation/cognitiveservices/v1?language=$language');

      final request = await HttpClient().postUrl(url);
      request.headers.set('Ocp-Apim-Subscription-Key', subscriptionKey);
      request.headers
          .set('Content-Type', 'audio/wav; codecs=audio/pcm; samplerate=16000');
      request.headers.set('Accept', 'application/json');

      final audioBytes = await audioFile.readAsBytes();
      request.add(audioBytes);

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(responseBody);
        final text = jsonResponse['DisplayText'] ?? '';
        debugPrint('Azure Speech transcription: $text');
        return text;
      } else {
        debugPrint(
            'Azure Speech error: ${response.statusCode} - $responseBody');
        throw Exception('Azure Speech API error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error transcribing with Azure Speech: $e');
      rethrow;
    } finally {
      // Delete wav file
      try {
        await File(wavPath).delete();
      } catch (e) {
        debugPrint('Error deleting temp file: $e');
      }
    }
  }

  @override
  Future<void> transcribeLive(
      Stream<Uint8List> voiceData, StreamController<String> out) async {
    final subscriptionKey = await getSubscriptionKey();
    final region = await getRegion();
    final language = _convertLanguageCode(await getLanguage());
    final bridgeServerUrl = await getBridgeServerUrl();

    if (subscriptionKey == null || subscriptionKey.isEmpty) {
      throw Exception("Azure Speech subscription key not set");
    }
    if (region == null || region.isEmpty) {
      throw Exception("Azure Speech region not set");
    }
    if (bridgeServerUrl == null || bridgeServerUrl.isEmpty) {
      throw Exception("Azure Bridge Server URL not set");
    }

    debugPrint('Starting live transcription with Azure Speech Bridge Server');
    debugPrint('Bridge server URL: $bridgeServerUrl');

    // Build WebSocket URL for bridge server
    final wsUrl = Uri.parse(bridgeServerUrl.replaceFirst('http', 'ws'));

    try {
      final socket = WebSocket(wsUrl);

      String accumulatedTranscription = '';
      bool isListening = true;

      // Listen to messages from bridge server
      socket.messages.listen((message) {
        try {
          debugPrint('Raw message from bridge: ${message.toString()}');

          if (message is String) {
            final jsonResponse = jsonDecode(message);
            final type = jsonResponse['type'];
            final text = jsonResponse['text'] ?? '';

            debugPrint('Bridge server message type: $type, text: $text');

            if (type == 'started') {
              debugPrint('Azure recognition started successfully');
            } else if (type == 'final' && text.isNotEmpty) {
              // Final recognition result
              if (accumulatedTranscription.isEmpty) {
                accumulatedTranscription = text;
              } else {
                accumulatedTranscription += ' ' + text;
              }

              if (accumulatedTranscription.length > 500) {
                accumulatedTranscription = _trimAtSentenceBoundary(
                  accumulatedTranscription,
                  400,
                );
              }

              out.add(accumulatedTranscription);
              debugPrint('Azure final transcription: $text');
            } else if (type == 'partial' && text.isNotEmpty) {
              // Partial/hypothesis result - send as real-time feedback
              // This replaces previous partial results until we get final
              String partialResult = accumulatedTranscription.isEmpty
                  ? text
                  : accumulatedTranscription + ' ' + text;

              if (partialResult.length > 500) {
                partialResult = _trimAtSentenceBoundary(
                  partialResult,
                  400,
                );
              }

              out.add(partialResult);
              debugPrint('Azure partial transcription: $text');
            } else if (type == 'error') {
              debugPrint('Azure error: ${jsonResponse['message']}');
              isListening = false;
            } else if (type == 'canceled') {
              debugPrint(
                  'Azure recognition canceled: ${jsonResponse['reason']}');
              isListening = false;
            } else if (type == 'sessionStopped') {
              debugPrint('Azure session stopped');
              isListening = false;
            }
          }
        } catch (e) {
          debugPrint('Error parsing bridge server message: $e');
        }
      }, onError: (error) {
        debugPrint('Bridge WebSocket error: $error');
        isListening = false;
      }, onDone: () {
        debugPrint('Bridge WebSocket connection closed');
        isListening = false;
      });

      // Wait for connection to be established
      // The web_socket_client automatically handles connection
      await Future.delayed(Duration(milliseconds: 500));

      // Send configuration to bridge server
      final configMessage = jsonEncode({
        'cmd': 'config',
        'key': subscriptionKey,
        'region': region,
        'language': language,
      });

      debugPrint('Sending config to bridge server: $configMessage');
      socket.send(configMessage);

      debugPrint('Config sent, waiting for recognition to start...');

      // Wait for Azure to initialize
      await Future.delayed(Duration(seconds: 1));

      // Stream audio data to bridge server (raw PCM data)
      await for (final data in voiceData) {
        if (!isListening) break;

        // Send raw PCM audio data (binary)
        socket.send(data);
      }

      debugPrint('Audio stream ended, sending stop command');

      // Send stop command
      socket.send(jsonEncode({'cmd': 'stop'}));

      // Wait a moment for final results
      await Future.delayed(Duration(seconds: 1));

      socket.close();
    } catch (e) {
      debugPrint('Error in Azure Speech bridge connection: $e');
      rethrow;
    }
  }

  String _trimAtSentenceBoundary(String text, int targetLength) {
    if (text.length <= targetLength) return text;

    final sentenceEnders = RegExp(r'[.!?]\s');
    final matches = sentenceEnders.allMatches(text);

    if (matches.isEmpty) {
      return text.substring(math.max(0, text.length - targetLength));
    }

    for (final match in matches.toList().reversed) {
      if (match.end <= targetLength) {
        continue;
      }
      if (match.start >= targetLength * 0.7) {
        return text.substring(0, match.end).trim();
      }
    }

    return text.substring(0, targetLength);
  }
}
