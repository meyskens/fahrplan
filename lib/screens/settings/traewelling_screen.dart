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
    });
  }

  Future<void> _saveCredentials() async {
    final username = _usernameController.text;
    final token = _tokenController.text;
    final apiURL = _apiUrlController.text;
    await _traewellingWidget.saveCredentials(username, token, apiURL);
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
