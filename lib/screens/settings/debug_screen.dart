import 'package:fahrplan/models/android/weather_data.dart';
import 'package:fahrplan/models/g1/calendar.dart';
import 'package:fahrplan/models/g1/dashboard.dart';
import 'package:fahrplan/models/g1/note.dart';
import 'package:fahrplan/models/g1/notification.dart';
import 'package:fahrplan/models/g1/time_weather.dart';
import 'package:fahrplan/services/bluetooth_manager.dart';
import 'package:fahrplan/utils/bitmap.dart';
import 'package:flutter/material.dart';

class DebugPage extends StatefulWidget {
  const DebugPage({super.key});

  @override
  State<DebugPage> createState() => _DebugPageSate();
}

class _DebugPageSate extends State<DebugPage> {
  final TextEditingController _textController = TextEditingController();
  final BluetoothManager bluetoothManager = BluetoothManager();

  int _seqId = 0;

  void _sendText() async {
    String text = _textController.text;
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter some text to send')),
      );
      return;
    }

    if (bluetoothManager.isConnected) {
      await bluetoothManager.sendText(text);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Glasses are not connected')),
      );
    }
  }

  void _sendNotification() async {
    String message = _textController.text;
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a message to send')),
      );
      return;
    }

    if (bluetoothManager.isConnected) {
      await bluetoothManager.sendNotification(NCSNotification(
          msgId: 1234567890,
          appIdentifier: "chat.fluffy.fluffychat",
          title: "Hello",
          subtitle: "subtitle",
          message: message,
          displayName: "DEV"));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Glasses are not connected')),
      );
    }
  }

  void _sendImage() async {
    var image = await generateDemoBMP();

    if (bluetoothManager.isConnected) {
      await bluetoothManager.sendBitmap(image);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Glasses are not connected')),
      );
    }
  }

  void _testCalendar() async {
    if (bluetoothManager.isConnected) {
      await bluetoothManager.setDashboardLayout(DashboardLayout.DASHBOARD_FULL);
      await bluetoothManager.sendCommandToGlasses(
        CalendarItem(
          location: "Test Place",
          name: "Test Event",
          time: "12:00",
        ).constructDashboardCalendarItem(),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Glasses are not connected')),
      );
    }
  }

  void _sendBadApple() async {
    if (bluetoothManager.isConnected) {
      for (var i = 1; i < 6500; i += 60) {
        // we have 0.5 fps so skipping some frames
        try {
          await bluetoothManager.sendBitmap(await generateBadAppleBMP(i));
        } catch (e) {
          debugPrint('Error sending frame: $e');
        }
        await Future.delayed(const Duration(milliseconds: 1000));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Glasses are not connected')),
      );
    }
  }

  void _sendNoteDemo() async {
    if (bluetoothManager.isConnected) {
      var note1 = Note(
        noteNumber: 1,
        name: 'Fahrplan',
        text:
            '☐ 09:00 Take medication\n☐ 09:18 Take bus 85\n☐ 09:58 take train to FN',
      );
      var note2 = Note(
        noteNumber: 2,
        name: 'Note 2',
        text: 'This is another note',
      );

      await bluetoothManager.sendNote(note1);
      await bluetoothManager.sendNote(note2);
      await bluetoothManager.setDashboardLayout(DashboardLayout.DASHBOARD_DUAL);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Glasses are not connected')),
      );
    }
  }

  void _debugTimeCommand() async {
    if (bluetoothManager.isConnected) {
      int temp = 5;
      int weatherIcon = WeatherIcons.SUNNY;

      final weather = await WeatherProvider.getWeather();
      if (weather != null) {
        temp = (weather.currentTemp ?? 0) - 273; // currentTemp is in kelvin
        weatherIcon = WeatherIcons.fromOpenWeatherMapConditionCode(
            weather.currentConditionCode ?? 0);
      }

      await bluetoothManager.sendCommandToGlasses(
        TimeAndWeather(
          temperatureUnit: TemperatureUnit.CELSIUS,
          timeFormat: TimeFormat.TWENTY_FOUR_HOUR,
          temperatureInCelsius: temp,
          weatherIcon: weatherIcon,
        ).buildAddCommand(_seqId++),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Glasses are not connected')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    // Optionally initiate scan here or via button
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Debug'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          TextField(
            controller: _textController,
            decoration: const InputDecoration(
              labelText: 'Enter text to send',
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: _sendText,
                child: const Text('Send Text'),
              ),
              ElevatedButton(
                onPressed: _sendNotification,
                child: const Text('Send Notification'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _sendImage,
            child: const Text("Send Image"),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _sendNoteDemo,
            child: const Text("Send Note Demo"),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _sendBadApple,
            child: const Text("Send Bad Apple"),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _testCalendar,
            child: const Text("Test Calendar"),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _debugTimeCommand,
            child: const Text("Debug Time/Weather Command"),
          ),
        ],
      ),
    );
  }
}
