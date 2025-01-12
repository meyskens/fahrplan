import 'package:fahrplan/models/fahrplan/whispermodel.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whisper_flutter_new/whisper_flutter_new.dart';

class WhisperSettingsPage extends StatefulWidget {
  const WhisperSettingsPage({super.key});

  @override
  WhisperSettingsPageState createState() => WhisperSettingsPageState();
}

class WhisperSettingsPageState extends State<WhisperSettingsPage> {
  final List<String> _models = FahrplanWhisperModel.models;
  final List<String> _languages = [
    'en',
    'es',
    'fr',
    'de',
    'it',
    'pt',
    'nl',
    'ru',
    'zh',
    'ja',
    'ko',
    'ar',
    'hi',
    'bn',
    'ur',
    'ta',
    'te',
    'mr',
    'gu',
    'kn',
    'ml',
    'pa',
    'th',
    'vi',
    'tl',
    'tr',
    'fa',
    'he',
    'sw'
  ];

  String? _selectedModel;
  String? _selectedMode;
  String? _selectedLanguage;

  final _apiUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _remoteModelController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSelectedModel();
  }

  Future<void> _loadSelectedModel() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedModel = prefs.getString('whisper_model') ?? 'base';
      _selectedMode = prefs.getString('whisper_mode') ?? 'local';
      _selectedLanguage = prefs.getString('whisper_language') ?? 'en';
      _apiUrlController.text = prefs.getString('whisper_api_url') ?? '';
      _apiKeyController.text = prefs.getString('whisper_api_key') ?? '';
      _remoteModelController.text =
          prefs.getString('whisper_remote_model') ?? '';
    });
  }

  Future<void> _saveSelectedModel(String model) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('whisper_model', model);
  }

  Future<void> _saveSelectedLanguage(String lang) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('whisper_language', lang);
  }

  Future<void> _saveSelectedMode(String mode) async {
    setState(() {
      _selectedMode = mode;
    });
    if (mode == "local") {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('whisper_mode', mode);
    }
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

  Future<void> _saveRemote() async {
    // Implement the logic to download the model here
    try {
      if (_apiUrlController.text.isEmpty) {
        throw Exception("API URL is required");
      }
      if (_remoteModelController.text.isEmpty) {
        throw Exception("Model is required");
      }

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('whisper_mode', _selectedMode!);
      await prefs.setString('whisper_api_url', _apiUrlController.text);
      await prefs.setString('whisper_api_key', _apiKeyController.text);
      await prefs.setString(
          'whisper_remote_model', _remoteModelController.text);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Whisper configuration saved!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final localOpts = [
      Text('Select Model:', style: TextStyle(fontSize: 18)),
      SizedBox(height: 10),
      DropdownButton<String>(
        value: _selectedModel,
        isExpanded: true,
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
        style: ElevatedButton.styleFrom(
          minimumSize: Size(double.infinity, 36), // Expand full width
        ),
        child: const Text('Download Model'),
      ),
    ];
    final remoteOpts = [
      Text('Whisper server details:', style: TextStyle(fontSize: 18)),
      SizedBox(height: 10),
      TextField(
        decoration: InputDecoration(labelText: 'API URL'),
        controller: _apiUrlController,
      ),
      SizedBox(height: 10),
      TextField(
        decoration: InputDecoration(labelText: 'API Key'),
        controller: _apiKeyController,
      ),
      SizedBox(height: 20),
      TextField(
        decoration: InputDecoration(labelText: 'Model'),
        controller: _remoteModelController,
      ),
      SizedBox(height: 20),
      ElevatedButton(
        onPressed: _saveRemote,
        style: ElevatedButton.styleFrom(
          minimumSize: Size(double.infinity, 36), // Expand full width
        ),
        child: Text('Save'),
      ),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text('Whisper Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Select Mode:', style: TextStyle(fontSize: 18)),
          SizedBox(height: 10),
          DropdownButton(
            value: _selectedMode,
            onChanged: (String? newValue) => _saveSelectedMode(newValue!),
            isExpanded: true,
            items: [
              DropdownMenuItem(
                value: "local",
                child: Text("Local"),
              ),
              DropdownMenuItem(
                value: "remote",
                child: Text("Remote"),
              )
            ],
          ),
          SizedBox(height: 20),
          Text('Select Language:', style: TextStyle(fontSize: 18)),
          SizedBox(height: 10),
          DropdownButton(
              value: _selectedLanguage,
              onChanged: (String? newValue) => _saveSelectedLanguage(newValue!),
              isExpanded: true,
              items: _languages.map<DropdownMenuItem<String>>((String lang) {
                return DropdownMenuItem<String>(
                  value: lang,
                  child: Text(lang),
                );
              }).toList()),
          ...(_selectedMode == "local" ? localOpts : remoteOpts),
        ]),
      ),
    );
  }
}
