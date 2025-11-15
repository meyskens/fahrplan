import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LLMSettingsPage extends StatefulWidget {
  const LLMSettingsPage({super.key});

  @override
  LLMSettingsPageState createState() => LLMSettingsPageState();
}

class LLMSettingsPageState extends State<LLMSettingsPage> {
  String? _voiceCommandMode;

  final _llmUrlController = TextEditingController();
  final _llmApiKeyController = TextEditingController();
  final _llmModelController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _voiceCommandMode = prefs.getString('voice_command_mode') ?? 'fuzzy';
      _llmUrlController.text = prefs.getString('llm_api_url') ?? '';
      _llmApiKeyController.text = prefs.getString('llm_api_key') ?? '';
      _llmModelController.text = prefs.getString('llm_model') ?? '';
    });
  }

  Future<void> _saveVoiceCommandMode(String mode) async {
    setState(() {
      _voiceCommandMode = mode;
    });
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('voice_command_mode', mode);
  }

  Future<void> _saveLLMSettings() async {
    try {
      if (_llmUrlController.text.isEmpty) {
        throw Exception("API URL is required");
      }
      if (_llmModelController.text.isEmpty) {
        throw Exception("Model is required");
      }

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('voice_command_mode', _voiceCommandMode!);
      await prefs.setString('llm_api_url', _llmUrlController.text);
      await prefs.setString('llm_api_key', _llmApiKeyController.text);
      await prefs.setString('llm_model', _llmModelController.text);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('LLM configuration saved!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final llmOpts = [
      Text('LLM Server Details:', style: TextStyle(fontSize: 18)),
      SizedBox(height: 10),
      TextField(
        decoration: InputDecoration(
          labelText: 'API URL',
        ),
        controller: _llmUrlController,
      ),
      SizedBox(height: 10),
      TextField(
        decoration: InputDecoration(
          labelText: 'API Key',
        ),
        controller: _llmApiKeyController,
        obscureText: true,
      ),
      SizedBox(height: 10),
      TextField(
        decoration: InputDecoration(
          labelText: 'Model',
        ),
        controller: _llmModelController,
      ),
      SizedBox(height: 20),
      ElevatedButton(
        onPressed: _saveLLMSettings,
        style: ElevatedButton.styleFrom(
          minimumSize: Size(double.infinity, 36),
        ),
        child: Text('Save LLM Configuration'),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('LLM Settings'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Voice Command Processing:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              DropdownButton(
                value: _voiceCommandMode,
                onChanged: (String? newValue) =>
                    _saveVoiceCommandMode(newValue!),
                isExpanded: true,
                items: [
                  DropdownMenuItem(
                    value: "fuzzy",
                    child: Text("Fuzzy Matching"),
                  ),
                  DropdownMenuItem(
                    value: "llm",
                    child: Text("LLM (Language Model)"),
                  ),
                ],
              ),
              SizedBox(height: 20),
              Text(
                _voiceCommandMode == "fuzzy"
                    ? 'Fuzzy matching uses pattern matching to recognize voice commands.'
                    : 'LLM uses a language model to understand natural language commands.',
                style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
              ),
              SizedBox(height: 30),
              if (_voiceCommandMode == "llm") ...llmOpts,
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _llmUrlController.dispose();
    _llmApiKeyController.dispose();
    _llmModelController.dispose();
    super.dispose();
  }
}
