import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MapboxSettingsPage extends StatefulWidget {
  const MapboxSettingsPage({super.key});

  @override
  MapboxSettingsPageState createState() => MapboxSettingsPageState();
}

class MapboxSettingsPageState extends State<MapboxSettingsPage> {
  final _apiKeyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _apiKeyController.text = prefs.getString('mapbox_api_key') ?? '';
    });
  }

  Future<void> _saveSettings() async {
    try {
      if (_apiKeyController.text.isEmpty) {
        throw Exception("API Key is required");
      }

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('mapbox_api_key', _apiKeyController.text);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mapbox API key saved!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapbox Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text(
            'Mapbox API Configuration',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'Get your API key from https://account.mapbox.com/',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          TextField(
            decoration: const InputDecoration(
              labelText: 'API Key',
              hintText: 'pk.eyJ1Ijoi...',
              border: OutlineInputBorder(),
            ),
            controller: _apiKeyController,
            obscureText: true,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _saveSettings,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 36),
            ),
            child: const Text('Save Configuration'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }
}
