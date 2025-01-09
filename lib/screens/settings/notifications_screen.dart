import 'dart:typed_data';

import 'package:fahrplan/models/g1/setup.dart';
import 'package:fahrplan/services/bluetooth_manager.dart';
import 'package:flutter/material.dart';
import 'package:android_package_manager/android_package_manager.dart';
import 'package:hive/hive.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  NotificationSettingsPageState createState() =>
      NotificationSettingsPageState();
}

class NotificationSettingsPageState extends State<NotificationSettingsPage> {
  List<ApplicationInfo> apps = [];
  List<ApplicationInfo> selectedApps = [];
  List<ApplicationInfo> filteredApps = [];
  List<String> selectedPkgNames = [];
  Map<String, Uint8List> icons = {};
  Map<String, String> labels = {};

  bool _loading = true;

  late Box selectedAppsBox;
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchApps();
    selectedAppsBox = Hive.box('fahrplanNotificationApps');
    searchController.addListener(_filterApps);
  }

  void fetchApps() async {
    List<ApplicationInfo> installedApps =
        await AndroidPackageManager().getInstalledApplications() ?? [];

    // fetch all icons
    for (var app in installedApps) {
      if (app.packageName == null) continue;
      icons[app.packageName!] = await app.getAppIcon() ?? Uint8List(0);
      labels[app.packageName!] = await app.getAppLabel() ?? '';
    }

    final selected = selectedAppsBox.toMap();
    selected.removeWhere((k, v) => !v);

    final newSelectedApps = <ApplicationInfo>[];

    for (var app in installedApps) {
      if (selected.containsKey(app.packageName)) {
        newSelectedApps.add(app);
      }
    }

    setState(() {
      apps = installedApps;
      selectedApps = newSelectedApps;
      selectedPkgNames = selected.keys.map((e) => e.toString()).toList();
      filteredApps = installedApps;
      _loading = false;
    });
  }

  void _filterApps() {
    final query = searchController.text.toLowerCase();
    setState(() {
      filteredApps = apps.where((app) {
        final label = labels[app.packageName]?.toLowerCase() ?? '';
        return label.contains(query);
      }).toList();
    });
  }

  void _handleAppToggle(ApplicationInfo app, bool state) async {
    setState(() {
      if (state) {
        selectedApps.add(app);
        selectedPkgNames.add(app.packageName ?? '');
      } else {
        selectedApps.remove(app);
        selectedPkgNames.remove(app.packageName);
      }
    });

    selectedAppsBox.put(app.packageName, state);

    final bt = BluetoothManager();
    final setup = await G1Setup.generateSetup().constructSetup();
    for (var command in setup) {
      await bt.sendCommandToGlasses(command);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Notification Settings'),
        ),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('Notification Settings'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text('Apps that show notifications on the G1',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                ...selectedApps.map((appInfo) {
                  return ListTile(
                    leading: Image.memory(
                        icons[appInfo.packageName] ?? Uint8List(0)),
                    title: Text(labels[appInfo.packageName] ?? ''),
                    subtitle: Text(appInfo.packageName ?? ''),
                    trailing: Checkbox(
                      value: selectedPkgNames.contains(appInfo.packageName),
                      onChanged: (value) =>
                          _handleAppToggle(appInfo, value ?? false),
                    ),
                  );
                }),
                Divider(),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text('System Apps',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Search apps...',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                ...filteredApps.map((appInfo) {
                  return ListTile(
                    leading: Image.memory(
                        icons[appInfo.packageName] ?? Uint8List(0)),
                    title: Text(labels[appInfo.packageName] ?? ''),
                    subtitle: Text(appInfo.packageName ?? ''),
                    trailing: Checkbox(
                      value: selectedAppsBox.get(appInfo.packageName,
                          defaultValue: false),
                      onChanged: (value) =>
                          _handleAppToggle(appInfo, value ?? false),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
