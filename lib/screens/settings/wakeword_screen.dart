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
  WakeWordEngine _selectedEngine = WakeWordEngine.snowboy;
  String _selectedSnowboyModel = 'snowboy.umdl';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final debugAccessKey = await WakeWordSettings.getDebugAccessKey();
    final releaseAccessKey = await WakeWordSettings.getReleaseAccessKey();
    final isEnabled = await WakeWordSettings.isEnabled();
    final engine = await WakeWordSettings.getEngine();
    final snowboyModel = await WakeWordSettings.getSnowboyModel();

    setState(() {
      _debugAccessKeyController.text = debugAccessKey;
      _releaseAccessKeyController.text = releaseAccessKey;
      // Only enable if there's an access key for the current mode
      _isEnabled = isEnabled;
      _selectedEngine = engine;
      _selectedSnowboyModel = snowboyModel;
    });
  }

  Future<void> _saveSettings() async {
    final currentAccessKey = kDebugMode
        ? _debugAccessKeyController.text.trim()
        : _releaseAccessKeyController.text.trim();

    // Only require access key for Porcupine engine
    if (_isEnabled &&
        _selectedEngine == WakeWordEngine.porcupine &&
        currentAccessKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Access key is required to enable Porcupine wake word detection for ${kDebugMode ? 'debug' : 'release'} mode'),
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
    await WakeWordSettings.setEngine(_selectedEngine);
    await WakeWordSettings.setSnowboyModel(_selectedSnowboyModel);

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
              'Wake Word Detection',
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
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Wake Word Engine',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    RadioListTile<WakeWordEngine>(
                      title: const Text('Porcupine'),
                      subtitle:
                          const Text('Requires API key from Picovoice Console'),
                      value: WakeWordEngine.porcupine,
                      groupValue: _selectedEngine,
                      onChanged: (WakeWordEngine? value) {
                        if (value != null) {
                          setState(() {
                            _selectedEngine = value;
                          });
                        }
                      },
                    ),
                    RadioListTile<WakeWordEngine>(
                      title: const Text('Snowboy'),
                      subtitle: const Text('Open-source, no API key required'),
                      value: WakeWordEngine.snowboy,
                      groupValue: _selectedEngine,
                      onChanged: (WakeWordEngine? value) {
                        if (value != null) {
                          setState(() {
                            _selectedEngine = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Enable Wake Word Detection'),
              subtitle: const Text(
                  'Detect wake word "Okay Glass" to trigger actions while looking at the Dashboard.'),
              value: _isEnabled,
              onChanged: (bool value) {
                if (value &&
                    _selectedEngine == WakeWordEngine.porcupine &&
                    currentAccessKey.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Please enter a Porcupine access key for ${kDebugMode ? 'debug' : 'release'} mode first'),
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
            // Only show Porcupine settings when Porcupine is selected
            if (_selectedEngine == WakeWordEngine.porcupine) ...[
              const Text(
                'Porcupine Settings',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
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
                  hintText:
                      'Enter your Porcupine access key for release builds',
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
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveSettings,
              child: const Text('Save Settings'),
            ),
            const SizedBox(height: 16),
            if (_selectedEngine == WakeWordEngine.snowboy) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Snowboy Model Selection',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedSnowboyModel,
                        decoration: const InputDecoration(
                          labelText: 'Wake Word Model',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.model_training),
                        ),
                        items: WakeWordSettings.snowboyModels.entries
                            .map((entry) => DropdownMenuItem<String>(
                                  value: entry.key,
                                  child: Text(entry.value),
                                ))
                            .toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedSnowboyModel = newValue;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'About Snowboy',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Snowboy is an open-source wake word detection engine. '
                        'It does not require an API key and works completely offline. '
                        'Multiple pre-trained models are available to choose from.',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
