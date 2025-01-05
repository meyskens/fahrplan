import 'dart:async';

import 'package:fahrplan/screens/calendars_screen.dart';
import 'package:fahrplan/screens/checklist_screen.dart';
import 'package:fahrplan/screens/fahrplan_daily.dart';
import 'package:fahrplan/screens/fahrplan_stop.dart';
import 'package:fahrplan/screens/settings_screen.dart';
import 'package:fahrplan/utils/ui_perfs.dart';
import 'package:fahrplan/widgets/current_fahrplan.dart';
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

  void _scanAndConnect() {
    try {
      bluetoothManager.startScanAndConnect(
        onUpdate: (_) => setState(() {}),
      );

      // run setState every second to update the UI as long bluetoothManager.isScanning is true
      Timer.periodic(const Duration(milliseconds: 300), (timer) {
        if (!bluetoothManager.isScanning) {
          timer.cancel();
        } else {
          setState(() {});
        }
      });
    } catch (e) {
      debugPrint('Error in _scanAndConnect: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
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
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  bluetoothManager.isConnected
                      ? const Text(
                          'Connected to G1 glasses',
                          style: TextStyle(color: Colors.green),
                        )
                      : ElevatedButton(
                          onPressed: bluetoothManager.isScanning
                              ? null
                              : _scanAndConnect,
                          child: bluetoothManager.isScanning
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(width: 10),
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    Text('Scanning for G1 glasses'),
                                  ],
                                )
                              : const Text('Connect to G1'),
                        ),
                ],
              ),
            ),
          ),
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
        ],
      ),
    );
  }
}
