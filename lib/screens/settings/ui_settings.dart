import 'package:fahrplan/utils/ui_perfs.dart';
import 'package:flutter/material.dart';

class UiSettingsPage extends StatefulWidget {
  const UiSettingsPage({super.key});

  @override
  UiSettingsPageState createState() => UiSettingsPageState();
}

class UiSettingsPageState extends State<UiSettingsPage> {
  late bool trainNerdmode;
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
          ],
        ),
      ),
    );
  }
}
