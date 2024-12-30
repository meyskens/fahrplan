import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class DashboardSettingsPage extends StatefulWidget {
  const DashboardSettingsPage({super.key});

  @override
  DashboardSettingsPageState createState() => DashboardSettingsPageState();
}

class DashboardSettingsPageState extends State<DashboardSettingsPage> {
  bool _is24HourFormat = true;
  bool _isCelsius = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _is24HourFormat = prefs.getBool('is24HourFormat') ?? true;
      _isCelsius = prefs.getBool('isCelsius') ?? true;
    });
  }

  Future<void> _saveSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is24HourFormat', _is24HourFormat);
    await prefs.setBool('isCelsius', _isCelsius);
  }

  void _launchURL(String to) async {
    final url = Uri.parse(to);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              title: _is24HourFormat
                  ? Text('24-hour time format')
                  : Text('12-hour time format'),
              value: _is24HourFormat,
              onChanged: (bool value) {
                setState(() {
                  _is24HourFormat = value;
                });
                _saveSettings();
              },
            ),
            SwitchListTile(
              title: _isCelsius
                  ? Text('Weather in Celsius')
                  : Text('Weather in Fahrenheit'),
              value: _isCelsius,
              onChanged: (bool value) {
                setState(() {
                  _isCelsius = value;
                });
                _saveSettings();
              },
            ),
            SizedBox(height: 20),
            Text(
              'Weather data is provided by your favorite weather app on Android using the Gadgetbridge protocol.',
              style: TextStyle(fontSize: 16),
            ),
            GestureDetector(
              onTap: () => _launchURL(
                  'https://gadgetbridge.org/internals/development/weather-support'),
              child: Text(
                'Learn more about Gadgetbridge weather support',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            SizedBox(height: 10),
            Text("Looking for a weather app?", style: TextStyle(fontSize: 16)),
            GestureDetector(
              onTap: () =>
                  _launchURL('https://f-droid.org/packages/org.breezyweather'),
              child: Text(
                'Try Breezy Weather!',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
