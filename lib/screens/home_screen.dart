import 'package:fahrplan/screens/calendars_screen.dart';
import 'package:fahrplan/screens/checklist_screen.dart';
import 'package:fahrplan/screens/fahrplan_daily.dart';
import 'package:fahrplan/screens/fahrplan_stop.dart';
import 'package:fahrplan/screens/settings_screen.dart';
import 'package:fahrplan/screens/transcribe_screen.dart';
import 'package:fahrplan/screens/webview_screen.dart';
import 'package:fahrplan/utils/ui_perfs.dart';
import 'package:fahrplan/widgets/current_fahrplan.dart';
import 'package:fahrplan/widgets/glass_status.dart';
import 'package:flutter/material.dart';
import '../services/bluetooth_manager.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final BluetoothManager bluetoothManager = BluetoothManager();
  final UiPerfs _ui = UiPerfs.singleton;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fahrplan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SettingsPage()),
              ).then((_) => setState(() {}));
            },
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          GlassStatus(),
          CurrentFahrplan(),
          ListTile(
            title: Row(
              children: [
                _ui.trainNerdMode
                    ? Image(
                        image: AssetImage('assets/icons/reference.png'),
                        height: 20,
                      )
                    : Icon(Icons.sunny),
                SizedBox(width: 10),
                Text('Daily Items'),
              ],
            ),
            trailing: Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => FahrplanDailyPage()),
              );
            },
          ),
          ListTile(
            title: Row(
              children: [
                _ui.trainNerdMode
                    ? Image(
                        image: AssetImage('assets/icons/stop.png'),
                        height: 20,
                      )
                    : Icon(Icons.notifications),
                SizedBox(width: 10),
                Text('Stop Items'),
              ],
            ),
            trailing: Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => FahrplanStopPage()),
              );
            },
          ),
          ListTile(
            title: Row(
              children: [
                _ui.trainNerdMode
                    ? Image(
                        image: AssetImage('assets/icons/oorsprong.png'),
                        height: 20,
                      )
                    : Icon(Icons.checklist),
                SizedBox(width: 10),
                Text('Checklists'),
              ],
            ),
            trailing: Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => FahrplanChecklistPage()),
              );
            },
          ),
          ListTile(
            title: Row(
              children: [
                _ui.trainNerdMode
                    ? Image(
                        image: AssetImage('assets/icons/tvm.png'),
                        height: 20,
                      )
                    : Icon(Icons.web),
                SizedBox(width: 10),
                Text('Web Views'),
              ],
            ),
            trailing: Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => FahrplanWebViewPage()),
              );
            },
          ),
          ListTile(
            title: Row(
              children: [
                _ui.trainNerdMode
                    ? Image(
                        image: AssetImage('assets/icons/groen.png'),
                        height: 20,
                      )
                    : Icon(Icons.calendar_today),
                SizedBox(width: 10),
                Text('Calendar Integration'),
              ],
            ),
            trailing: Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CalendarsPage()),
              );
            },
          ),
          ListTile(
            title: Row(
              children: [
                _ui.trainNerdMode
                    ? Image(
                        image: AssetImage('assets/icons/gsmr.png'),
                        height: 20,
                      )
                    : Icon(Icons.transcribe),
                SizedBox(width: 10),
                Text('Transcribe'),
              ],
            ),
            trailing: Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => TranscribeScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}
