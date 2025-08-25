import 'package:fahrplan/utils/wakeword_settings.dart';
import 'package:flutter/material.dart';

class WakeWordSettingsPage extends StatefulWidget {
  const WakeWordSettingsPage({super.key});

  @override
  WakeWordSettingsPageState createState() => WakeWordSettingsPageState();
}

class WakeWordSettingsPageState extends State<WakeWordSettingsPage> {
  final _accessKeyController = TextEditingController();
  bool _isEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final accessKey = await WakeWordSettings.getAccessKey();
    final isEnabled = await WakeWordSettings.isEnabled();

    setState(() {
      _accessKeyController.text = accessKey;
      // Only enable if there's an access key
      _isEnabled = isEnabled && accessKey.isNotEmpty;
    });
  }

  Future<void> _saveSettings() async {
    if (_isEnabled && _accessKeyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Access key is required to enable wake word detection'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await WakeWordSettings.setAccessKey(_accessKeyController.text.trim());
    await WakeWordSettings.setEnabled(_isEnabled);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wake word settings saved')),
      );
    }
  }

  @override
  void dispose() {
    _accessKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wake Word Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            const Text(
              'Porcupine Wake Word Detection',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Enable Wake Word Detection'),
              subtitle:
                  const Text('Detect wake words like "Computer" or "Alexa"'),
              value: _isEnabled,
              onChanged: (bool value) {
                if (value && _accessKeyController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter an access key first'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                setState(() {
                  _isEnabled = value;
                });
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _accessKeyController,
              decoration: InputDecoration(
                labelText: 'Porcupine Access Key *',
                hintText: 'Enter your Porcupine access key (required)',
                border: const OutlineInputBorder(),
                errorText: _accessKeyController.text.trim().isEmpty
                    ? 'Access key is required'
                    : null,
              ),
              maxLines: 2,
              onChanged: (value) {
                setState(() {
                  // Refresh UI to update error text
                });
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Get your free access key from Picovoice Console (https://console.picovoice.ai/)',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveSettings,
              child: const Text('Save Settings'),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'About Wake Word Detection',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Wake word detection allows your device to listen for specific trigger words like "Computer" or "Alexa" to activate voice commands. This feature uses Porcupine by Picovoice.',
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'You need a valid Porcupine access key to use this feature. You can get a free access key by signing up at the Picovoice Console.',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
