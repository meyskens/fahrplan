import 'dart:io';
import 'dart:typed_data';

import 'package:fahrplan/utils/wakeword_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_snowboy/flutter_snowboy.dart';
import 'package:path_provider/path_provider.dart';
import 'package:porcupine_flutter/porcupine.dart';
import 'package:porcupine_flutter/porcupine_error.dart';

/// Abstract interface for wake word detection engines
abstract class WakeWordDetector {
  /// Callback to be invoked when wake word is detected
  void Function()? onWakeWordDetected;

  /// Initialize the wake word detector
  Future<void> initialize();

  /// Process audio data and detect wake word
  /// Returns true if wake word is detected
  Future<bool> processFile(File wavFile);

  /// Clean up resources
  void dispose();

  /// Factory method to create the appropriate detector based on settings
  static Future<WakeWordDetector?> create(
      {void Function()? onWakeWordDetected}) async {
    final engine = await WakeWordSettings.getEngine();

    switch (engine) {
      case WakeWordEngine.porcupine:
        final accessKey = await WakeWordSettings.getAccessKey();
        if (accessKey.trim().isEmpty) {
          debugPrint("No Porcupine access key provided");
          return null;
        }
        return PorcupineDetector(accessKey)
          ..onWakeWordDetected = onWakeWordDetected;

      case WakeWordEngine.snowboy:
        return SnowboyDetector()..onWakeWordDetected = onWakeWordDetected;
    }
  }
}

/// Porcupine wake word detector implementation
class PorcupineDetector implements WakeWordDetector {
  final String accessKey;
  Porcupine? _porcupine;

  @override
  void Function()? onWakeWordDetected;

  PorcupineDetector(this.accessKey);

  @override
  Future<void> initialize() async {
    try {
      _porcupine = await Porcupine.fromKeywordPaths(
        accessKey,
        ["assets/okay-glass.ppn"],
      );
    } on PorcupineException catch (err) {
      debugPrint("Failed to create Porcupine: $err");
      rethrow;
    }
  }

  @override
  Future<bool> processFile(File wavFile) async {
    if (_porcupine == null) {
      await initialize();
    }

    if (_porcupine == null) {
      return false;
    }

    final raf = wavFile.openSync(mode: FileMode.read);

    try {
      // Parse WAV header (44 bytes for PCM)
      final header = raf.readSync(44);
      final byteData = ByteData.sublistView(header);

      final channels = byteData.getUint16(22, Endian.little);
      final sampleRate = byteData.getUint32(24, Endian.little);
      final bitsPerSample = byteData.getUint16(34, Endian.little);

      if (channels != 1 || sampleRate != 16000 || bitsPerSample != 16) {
        debugPrint(
          "Porcupine requires 16kHz, 16-bit PCM, mono audio. "
          "File: $channels ch, $sampleRate Hz, $bitsPerSample bits",
        );
        return false;
      }

      // Read audio in chunks
      final frameLength = _porcupine!.frameLength;
      final bufferSize = frameLength * 2; // 16-bit PCM => 2 bytes per sample
      final frameBuffer = Uint8List(bufferSize);

      while (true) {
        final bytesRead = raf.readIntoSync(frameBuffer);
        if (bytesRead < bufferSize) break;

        final samples = Int16List.view(frameBuffer.buffer, 0, frameLength);
        final result = await _porcupine!.process(samples);

        if (result >= 0) {
          onWakeWordDetected?.call();
          return true;
        }
      }

      return false;
    } finally {
      raf.closeSync();
    }
  }

  @override
  void dispose() {
    _porcupine?.delete();
    _porcupine = null;
  }
}

/// Snowboy wake word detector implementation
class SnowboyDetector implements WakeWordDetector {
  Snowboy? _snowboy;
  bool _detectionResult = false;

  // Store the past 2 samples for context injection
  final List<Uint8List> _pastSamples = [];
  static const int _maxPastSamples = 2;

  @override
  void Function()? onWakeWordDetected;

  /// Copy model from asset bundle to temp directory on the filesystem
  static Future<String> _copyModelToFilesystem(String assetPath) async {
    final String dir = (await getTemporaryDirectory()).path;
    final String filename = assetPath.split('/').last;
    final String finalPath = "$dir/$filename";

    if (await File(finalPath).exists() == true) {
      // Don't overwrite existing file
      return finalPath;
    }

    ByteData bytes = await rootBundle.load(assetPath);
    final buffer = bytes.buffer;
    await File(finalPath).writeAsBytes(
        buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));
    return finalPath;
  }

  @override
  Future<void> initialize() async {
    try {
      // Initialize Snowboy with model file
      // Get the selected model from settings
      final selectedModel = await WakeWordSettings.getSnowboyModel();

      // First copy the model from assets to filesystem
      final String modelPath =
          await _copyModelToFilesystem('assets/snowboy/$selectedModel');

      _snowboy = Snowboy();

      // Set up the hotword detection handler
      _snowboy!.hotwordHandler = () {
        debugPrint("Snowboy: Wake word detected!");
        _detectionResult = true;
        onWakeWordDetected?.call();
      };

      // Prepare Snowboy with the filesystem model path
      final success = await _snowboy!.prepare(
        modelPath,
        sensitivity: 0.5,
        audioGain: 1.0,
        applyFrontend: false,
      );

      if (!success) {
        throw Exception("Failed to prepare Snowboy");
      }
    } catch (err) {
      debugPrint("Failed to create Snowboy: $err");
      rethrow;
    }
  }

  @override
  Future<bool> processFile(File wavFile) async {
    if (_snowboy == null) {
      await initialize();
    }

    if (_snowboy == null) {
      return false;
    }

    try {
      // Reset detection result
      _detectionResult = false;

      // Read the entire WAV file
      final bytes = await wavFile.readAsBytes();

      // Skip WAV header (44 bytes) and get PCM data
      final pcmData = Uint8List.sublistView(bytes, 44);

      // Create combined data with past 2 samples injected before current sample
      final List<int> combinedData = [];

      // Add the past samples first (in chronological order)
      for (final pastSample in _pastSamples) {
        combinedData.addAll(pastSample);
      }

      // Add the current sample
      combinedData.addAll(pcmData);

      // Convert to Uint8List for processing
      final dataToProcess = Uint8List.fromList(combinedData);

      // Process the audio data with injected past samples
      await _snowboy!.detect(dataToProcess);

      // Store current sample for future use
      _pastSamples.add(pcmData);

      // Keep only the last 2 samples
      if (_pastSamples.length > _maxPastSamples) {
        _pastSamples.removeAt(0);
      }

      // Return the detection result
      return _detectionResult;
    } catch (e) {
      debugPrint("Error processing with Snowboy: $e");
      return false;
    }
  }

  @override
  void dispose() {
    _snowboy?.purge();
    _snowboy = null;
    _pastSamples.clear();
  }
}
