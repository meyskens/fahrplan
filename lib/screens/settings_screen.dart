import 'package:fahrplan/screens/settings/debug_screen.dart';
import 'package:fahrplan/screens/settings/traewelling_screen.dart';
import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
      ),
      body: ListView(
        children: [
          ListTile(
            title: const Row(children: [
              Icon(Icons.train),
              SizedBox(width: 10),
              Text('Träwelling'),
            ]),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => TraewellingSettingsPage()),
              );
            },
          ),
          ListTile(
            title: const Row(children: [
              Icon(Icons.bug_report),
              SizedBox(width: 10),
              Text('Debug'),
            ]),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => DebugPage()),
              );
            },
          ),
        ],
      ),
    );
  }
}
