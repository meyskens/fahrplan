import 'package:fahrplan/models/fahrplan/widgets/traewelling.dart';
import 'package:flutter/material.dart';

class TraewellingSettingsPage extends StatefulWidget {
  const TraewellingSettingsPage({super.key});

  @override
  TraewellingSettingsPageState createState() => TraewellingSettingsPageState();
}

class TraewellingSettingsPageState extends State<TraewellingSettingsPage> {
  final _usernameController = TextEditingController();
  final _tokenController = TextEditingController();
  final _apiUrlController = TextEditingController();
  final TraewellingWidget _traewellingWidget = TraewellingWidget();

  bool trainConductorMode = false;

  @override
  void initState() {
    super.initState();
    _loadCredentials();
  }

  Future<void> _loadCredentials() async {
    await _traewellingWidget.loadCredentials();
    setState(() {
      _usernameController.text = _traewellingWidget.username ?? '';
      _tokenController.text = _traewellingWidget.token ?? '';
      _apiUrlController.text = _traewellingWidget.apiURL ?? '';
      trainConductorMode = _traewellingWidget.trainConductorMode;
    });
  }

  Future<void> _saveCredentials() async {
    final username = _usernameController.text;
    final token = _tokenController.text;
    final apiURL = _apiUrlController.text;
    await _traewellingWidget.saveCredentials(
        username, token, apiURL, trainConductorMode);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Credentials saved')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Träwelling Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            TextField(
              controller: _apiUrlController,
              decoration: InputDecoration(labelText: 'API URL'),
            ),
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(labelText: 'Username'),
            ),
            TextField(
              controller: _tokenController,
              decoration: InputDecoration(labelText: 'Token'),
            ),
            SwitchListTile(
              title: Text('I am a train conductor'),
              value: trainConductorMode,
              onChanged: (bool value) {
                setState(() {
                  trainConductorMode = value;
                });
              },
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveCredentials,
              child: Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
