import 'dart:io';

import 'package:fahrplan/utils/ui_perfs.dart';
import 'package:flutter/material.dart';

class UiSettingsPage extends StatefulWidget {
  const UiSettingsPage({super.key});

  @override
  UiSettingsPageState createState() => UiSettingsPageState();
}

class UiSettingsPageState extends State<UiSettingsPage> {
  late bool trainNerdmode;
  late bool backgroundAudioKeepAlive;
  late UiPerfs _uiPerfs;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _uiPerfs = UiPerfs.singleton;
    await _uiPerfs.load();

    setState(() {
      trainNerdmode = _uiPerfs.trainNerdMode;
      backgroundAudioKeepAlive = _uiPerfs.backgroundAudioKeepAlive;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('UI Preferences'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              title: Text('Train Nerd Mode'),
              value: _uiPerfs.trainNerdMode,
              onChanged: (bool value) {
                _uiPerfs.trainNerdMode = value;
                setState(() {
                  trainNerdmode = value;
                });
              },
            ),
            if (Platform.isIOS || Platform.isAndroid)
              SwitchListTile(
                title: Text('Background Audio Keep-Alive'),
                subtitle: Text(
                  'Play silent audio to maintain BLE connection when app is backgrounded. '
                  'May increase battery usage.',
                ),
                value: _uiPerfs.backgroundAudioKeepAlive,
                onChanged: (bool value) {
                  _uiPerfs.backgroundAudioKeepAlive = value;
                  setState(() {
                    backgroundAudioKeepAlive = value;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }
}
