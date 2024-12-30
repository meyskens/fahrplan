import 'package:fahrplan/screens/settings/dashboard_screen.dart';
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
            title: Row(
              children: [
                Icon(Icons.dashboard),
                SizedBox(width: 10),
                Text('G1 Dashboard'),
              ],
            ),
            trailing: Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => DashboardSettingsPage()),
              );
            },
          ),
          ListTile(
            title: Row(
              children: [
                Icon(Icons.train),
                SizedBox(width: 10),
                Text('Träwelling'),
              ],
            ),
            trailing: Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => TraewellingSettingsPage()),
              );
            },
          ),
          ListTile(
            title: Row(
              children: [
                Icon(Icons.bug_report),
                SizedBox(width: 10),
                Text('Debug'),
              ],
            ),
            trailing: Icon(Icons.chevron_right),
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
