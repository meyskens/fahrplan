import 'dart:async';
import 'dart:typed_data';

import 'package:fahrplan/services/bluetooth_reciever.dart';
import 'package:fahrplan/utils/lc3.dart';
import 'package:flutter/material.dart';
import 'package:fahrplan/services/bluetooth_manager.dart';
import 'package:fahrplan/models/g1/translate.dart';
import 'package:fahrplan/services/whisper.dart';

class TranscribeScreen extends StatefulWidget {
  const TranscribeScreen({super.key});

  @override
  State<TranscribeScreen> createState() => _TranscribeScreenState();
}

class _TranscribeScreenState extends State<TranscribeScreen> {
  final BluetoothManager bluetoothManager = BluetoothManager();
  final TextEditingController _textController = TextEditingController();
  WhisperService? wr;
  Timer? fetchVoiceTimer;

  StreamController<Uint8List>? voiceData;
  StreamController<String>? textStream;

  void _startTranscription() async {
    wr ??= await WhisperService.service();
    if (!bluetoothManager.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Glasses are not connected')),
      );
      return;
    }

    final tr = Translate(
        fromLanguage: TranslateLanguages.FRENCH,
        toLanguage: TranslateLanguages.ENGLISH);
    await bluetoothManager.sendCommandToGlasses(tr.buildSetupCommand());
    await bluetoothManager.rightGlass!
        .sendData(tr.buildRightGlassStartCommand());
    for (var cmd in tr.buildInitalScreenLoad()) {
      await bluetoothManager.sendCommandToGlasses(cmd);
    }
    await Future.delayed(const Duration(milliseconds: 200));
    await bluetoothManager.setMicrophone(true);

    voiceData = StreamController<Uint8List>();
    textStream = StreamController<String>();

    final btr = BluetoothReciever();
    btr.voiceCollectorAI.isRecording = true;

    fetchVoiceTimer = Timer.periodic(Duration(milliseconds: 200), (_) async {
      final lc3Data = await btr.voiceCollectorAI.getAllDataAndReset();
      final pcm = await LC3.decodeLC3(Uint8List.fromList(lc3Data));
      if (pcm.isNotEmpty) {
        voiceData?.add(pcm);
      }
    });

    wr!.transcribeLive(voiceData!.stream, textStream!);

    await for (String line in textStream!.stream) {
      if (line.length > 220) {
        line = line.substring(line.length - 220);
      }
      setState(() {
        _textController.text = line;
      });

      await bluetoothManager
          .sendCommandToGlasses(tr.buildTranslatedCommand(line));
      await bluetoothManager
          .sendCommandToGlasses(tr.buildOriginalCommand(line));
    }
  }

  void _stopTranscription() async {
    await bluetoothManager.setMicrophone(false);
    fetchVoiceTimer?.cancel();
    voiceData?.close();
    textStream?.close();

    final btr = BluetoothReciever();
    btr.voiceCollectorAI.isRecording = false;
    btr.voiceCollectorAI.reset();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transcribe and Translate'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _startTranscription,
              child: const Text('Start Transcription'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _stopTranscription,
              child: const Text('Stop Transcription'),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _textController,
              decoration: const InputDecoration(
                labelText: 'Transcribed Text',
              ),
              readOnly: true,
              maxLines: null,
              minLines: 3,
              keyboardType: TextInputType.multiline,
            ),
          ],
        ),
      ),
    );
  }
}
