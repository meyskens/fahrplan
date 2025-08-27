import 'package:fahrplan/utils/wakeword_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class WakeWordSettingsPage extends StatefulWidget {
  const WakeWordSettingsPage({super.key});

  @override
  WakeWordSettingsPageState createState() => WakeWordSettingsPageState();
}

class WakeWordSettingsPageState extends State<WakeWordSettingsPage> {
  final _debugAccessKeyController = TextEditingController();
  final _releaseAccessKeyController = TextEditingController();
  bool _isEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final debugAccessKey = await WakeWordSettings.getDebugAccessKey();
    final releaseAccessKey = await WakeWordSettings.getReleaseAccessKey();
    final isEnabled = await WakeWordSettings.isEnabled();

    setState(() {
      _debugAccessKeyController.text = debugAccessKey;
      _releaseAccessKeyController.text = releaseAccessKey;
      // Only enable if there's an access key for the current mode
      _isEnabled = isEnabled;
    });
  }

  Future<void> _saveSettings() async {
    final currentAccessKey = kDebugMode
        ? _debugAccessKeyController.text.trim()
        : _releaseAccessKeyController.text.trim();

    if (_isEnabled && currentAccessKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Access key is required to enable wake word detection for ${kDebugMode ? 'debug' : 'release'} mode'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await WakeWordSettings.setDebugAccessKey(
        _debugAccessKeyController.text.trim());
    await WakeWordSettings.setReleaseAccessKey(
        _releaseAccessKeyController.text.trim());
    await WakeWordSettings.setEnabled(_isEnabled);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wake word settings saved')),
      );
    }
  }

  @override
  void dispose() {
    _debugAccessKeyController.dispose();
    _releaseAccessKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentAccessKey = kDebugMode
        ? _debugAccessKeyController.text.trim()
        : _releaseAccessKeyController.text.trim();

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
            const SizedBox(height: 8),
            Text(
              'Currently running in ${kDebugMode ? 'DEBUG' : 'RELEASE'} mode',
              style: TextStyle(
                fontSize: 14,
                color: kDebugMode ? Colors.orange : Colors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Enable Wake Word Detection'),
              subtitle: const Text(
                  'Detect wake word "Okay Glass" to trigger actions while looking at the Dashboard.'),
              value: _isEnabled,
              onChanged: (bool value) {
                if (value && currentAccessKey.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Please enter an access key for ${kDebugMode ? 'debug' : 'release'} mode first'),
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
              controller: _debugAccessKeyController,
              decoration: InputDecoration(
                labelText: 'Debug Mode Access Key',
                hintText: 'Enter your Porcupine access key for debug builds',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(Icons.bug_report, color: Colors.orange),
                errorText: kDebugMode &&
                        _debugAccessKeyController.text.trim().isEmpty &&
                        _isEnabled
                    ? 'Access key is required for debug mode'
                    : null,
              ),
              maxLines: 2,
              onChanged: (value) {
                setState(() {
                  // Refresh UI to update error text
                });
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _releaseAccessKeyController,
              decoration: InputDecoration(
                labelText: 'Release Mode Access Key',
                hintText: 'Enter your Porcupine access key for release builds',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(Icons.rocket_launch, color: Colors.green),
                errorText: !kDebugMode &&
                        _releaseAccessKeyController.text.trim().isEmpty &&
                        _isEnabled
                    ? 'Access key is required for release mode'
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
                      'About Separate Access Keys',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'As Picovoice does not see an app in release and debug mode as the same app, separate access keys are required for each mode. While this is technically not okay, there is no way around it at the moment.',
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
