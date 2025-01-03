import 'package:fahrplan/models/fahrplan/whispermodel.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whisper_flutter_new/whisper_flutter_new.dart';

class WhisperSettingsPage extends StatefulWidget {
  @override
  WhisperSettingsPageState createState() => WhisperSettingsPageState();
}

class WhisperSettingsPageState extends State<WhisperSettingsPage> {
  final List<String> _models = FahrplanWhisperModel.models;
  String? _selectedModel;

  @override
  void initState() {
    super.initState();
    _loadSelectedModel();
  }

  Future<void> _loadSelectedModel() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedModel = prefs.getString('whisper_model') ?? 'base';
    });
  }

  Future<void> _saveSelectedModel(String model) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('whisper_model', model);
  }

  Future<void> _downloadModel() async {
    // Implement the logic to download the model here
    final Whisper whisper = Whisper(
        model: FahrplanWhisperModel(_selectedModel!).model,
        downloadHost:
            "https://huggingface.co/ggerganov/whisper.cpp/resolve/main");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Downloading model: $_selectedModel')),
    );

    try {
      await whisper.transcribe(
          transcribeRequest: TranscribeRequest(
        audio: "noexist.wav",
      ));
    } catch (e) {}

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Model $_selectedModel downloaded')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Whisper Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select Model:', style: TextStyle(fontSize: 18)),
            SizedBox(height: 10),
            DropdownButton<String>(
              value: _selectedModel,
              onChanged: (String? newValue) {
                setState(() {
                  _selectedModel = newValue;
                });
                _saveSelectedModel(newValue!);
              },
              items: _models.map<DropdownMenuItem<String>>((String model) {
                return DropdownMenuItem<String>(
                  value: model,
                  child: Text(model),
                );
              }).toList(),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _downloadModel,
              child: Text('Download Model'),
            ),
          ],
        ),
      ),
    );
  }
}
