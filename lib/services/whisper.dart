import 'dart:convert';
import 'dart:io';

import 'package:dart_openai/dart_openai.dart';
import 'package:fahrplan/models/fahrplan/whispermodel.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:whisper_flutter_new/whisper_flutter_new.dart';

abstract class WhisperService {
  Future<String> transcribe(Uint8List voiceData);
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
        language: prefs.getString('whisper_language') ?? 'en',
      ),
    );

    // delete wav file
    await File(wavPath).delete();

    return transcription.text;
  }
}

class WhisperRemoteService implements WhisperService {
  Future<String?> getBaseURL() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('whisper_remote_url');
  }

  Future<String?> getApiKey() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('whisper_remote_api_key');
  }

  Future<String?> getModel() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('whisper_remote_model');
  }

  Future<String?> getLanguage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('whisper_language');
  }

  void init() async {
    final url = await getBaseURL();
    if (url == null) {
      throw Exception("no Whisper Remote URL set");
    }
    OpenAI.baseUrl = url;
    OpenAI.apiKey = await getApiKey() ?? '';
  }

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

    OpenAIAudioModel transcription =
        await OpenAI.instance.audio.createTranscription(
      file: File(wavPath),
      model: await getModel() ?? '',
      responseFormat: OpenAIAudioResponseFormat.json,
      language: await getLanguage(),
    );

    // delete wav file
    await File(wavPath).delete();

    var text = transcription.text;

    return text;
  }
}
