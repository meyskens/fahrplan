import 'package:fahrplan/models/fahrplan/widgets/homassistant.dart';
import 'package:flutter/material.dart';

class HomeAssistantSettingsPage extends StatefulWidget {
  const HomeAssistantSettingsPage({super.key});

  @override
  HomeAssistantSettingsPageState createState() =>
      HomeAssistantSettingsPageState();
}

class HomeAssistantSettingsPageState extends State<HomeAssistantSettingsPage> {
  final _urlController = TextEditingController();
  final _tokenController = TextEditingController();
  final HomeAssistantWidget _homeassistantWidget = HomeAssistantWidget();

  @override
  void initState() {
    super.initState();
    _loadCredentials();
  }

  Future<void> _loadCredentials() async {
    await _homeassistantWidget.loadCredentials();
    setState(() {
      _urlController.text = _homeassistantWidget.url ?? '';
      _tokenController.text = _homeassistantWidget.token ?? '';
    });
  }

  Future<void> _saveCredentials() async {
    String username = _urlController.text;
    String token = _tokenController.text;
    await _homeassistantWidget.saveCredentials(username, token);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Credentials saved')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('HomeAssistant Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            TextField(
              controller: _urlController,
              decoration: InputDecoration(labelText: 'URL'),
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
