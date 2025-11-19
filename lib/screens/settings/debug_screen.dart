import 'package:fahrplan/models/android/weather_data.dart';
import 'package:fahrplan/models/g1/calendar.dart';
import 'package:fahrplan/models/g1/dashboard.dart';
import 'package:fahrplan/models/g1/navigation.dart';
import 'package:fahrplan/models/g1/note.dart';
import 'package:fahrplan/models/g1/notification.dart';
import 'package:fahrplan/models/g1/time_weather.dart';
import 'package:fahrplan/models/g1/translate.dart';
import 'package:fahrplan/services/bluetooth_manager.dart';
import 'package:fahrplan/utils/bitmap.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DebugPage extends StatefulWidget {
  const DebugPage({super.key});

  @override
  State<DebugPage> createState() => _DebugPageSate();
}

class _DebugPageSate extends State<DebugPage> {
  final TextEditingController _textController = TextEditingController();
  final BluetoothManager bluetoothManager = BluetoothManager();

  int _seqId = 0;
  bool _enableUntestedFeatures = false;

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

  void _debugTranslateCommand() async {
    if (bluetoothManager.isConnected) {
      final tr = Translate(
          fromLanguage: TranslateLanguages.FRENCH,
          toLanguage: TranslateLanguages.ENGLISH);
      await bluetoothManager.sendCommandToGlasses(tr.buildSetupCommand());
      await bluetoothManager.rightGlass!
          .sendData(tr.buildRightGlassStartCommand());
      for (var cmd in tr.buildInitalScreenLoad()) {
        await bluetoothManager.sendCommandToGlasses(cmd);
      }
      await Future.delayed(const Duration(milliseconds: 200));
      await bluetoothManager.setMicrophone(true);

      final demoText = [
        "Hello and welcome to Fahrplan",
        "These glasses cured my autism!",
        "haha no just kidding but they are amazing",
        "you are watching a demo of translation",
        "but nobody is talking??",
        "that is why I said DEMO...",
        "anyway enjoy Fahrplan",
        "and don't forget to like and subscribe"
      ];
      final demoTextFrench = [
        "Bonjour et bienvenue à Fahrplan",
        "Ces lunettes ont guéri mon autisme!",
        "haha non je rigole mais elles sont incroyables",
        "vous regardez une démo de traduction",
        "mais personne ne parle??",
        "c'est pourquoi j'ai dit DEMO...",
        "de toute façon, profitez de Fahrplan",
        "et n'oubliez pas de liker et de vous abonner"
      ];
      for (var i = 0; i < demoText.length; i++) {
        await bluetoothManager
            .sendCommandToGlasses(tr.buildTranslatedCommand(demoText[i]));
        await bluetoothManager
            .sendCommandToGlasses(tr.buildOriginalCommand(demoTextFrench[i]));
        await Future.delayed(const Duration(seconds: 4));
      }
      await bluetoothManager.setMicrophone(false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Glasses are not connected')),
      );
    }
  }

  void _debugNavigationCommand() async {
    if (bluetoothManager.isConnected) {
      // Initialize navigation (like Swift's initData)
      await bluetoothManager.startNavigation();
      await Future.delayed(const Duration(milliseconds: 8));
      debugPrint('Started navigation mode');

      // Demo navigation sequence - matches Swift implementation structure
      final directions = [
        {
          'totalDuration': '15 mins',
          'totalDistance': '2500m',
          'direction': 'Continue straight',
          'distance': '500m',
          'speed': '30km/h',
          'turn': DirectionTurn.straight,
          'x': 244, // position on secondary map (488/2)
          'y': 68, // position on secondary map (136/2)
        },
        {
          'totalDuration': '12 mins',
          'totalDistance': '2000m',
          'direction': 'Turn right',
          'distance': '200m',
          'speed': '25km/h',
          'turn': DirectionTurn.right,
          'x': 250,
          'y': 70,
        },
        {
          'totalDuration': '10 mins',
          'totalDistance': '1500m',
          'direction': 'Slight left',
          'distance': '300m',
          'speed': '35km/h',
          'turn': DirectionTurn.slightLeft,
          'x': 240,
          'y': 65,
        },
        {
          'totalDuration': '7 mins',
          'totalDistance': '1000m',
          'direction': 'Turn left',
          'distance': '150m',
          'speed': '20km/h',
          'turn': DirectionTurn.left,
          'x': 235,
          'y': 68,
        },
        {
          'totalDuration': '5 mins',
          'totalDistance': '800m',
          'direction': 'Continue straight',
          'distance': '800m',
          'speed': '40km/h',
          'turn': DirectionTurn.straight,
          'x': 244,
          'y': 68,
        },
      ];

      await bluetoothManager.sendNavigationPoller();

      // Generate and send primary image (136x136) - road map + overlay
      final primaryImage = _generateDemoRoadMap(136, 136);
      final primaryOverlay = _generateDemoOverlay(136, 136, 1);
      //await bluetoothManager.sendNavigationPrimaryImage(
      //  image: primaryImage,
      //  overlay: primaryOverlay,
      //);
      await Future.delayed(const Duration(milliseconds: 8));

      debugPrint('Sent primary navigation image');

      // Generate and send secondary image (488x136) - wider view
      final secondaryImage = _generateDemoRoadMap(488, 136);
      final secondaryOverlay =
          _generateDemoOverlay(488, 136, 0, position: (1, 1));
      //await bluetoothManager.sendNavigationSecondaryImage(
      //  image: secondaryImage,
      //  overlay: secondaryOverlay,
      //);

      debugPrint('Sent secondary navigation image');

      await bluetoothManager.sendNavigationPoller();

      for (var i = 0; i < directions.length; i++) {
        await bluetoothManager.sendNavigationPoller();
        var direction = directions[i];

        // Send directions data with position (like Swift's directionsData)
        final xPos = direction['x'] as int;
        final yPos = direction['y'] as int;
        await bluetoothManager.sendNavigationDirections(
          totalDuration: direction['totalDuration'] as String,
          totalDistance: direction['totalDistance'] as String,
          direction: direction['direction'] as String,
          distance: direction['distance'] as String,
          speed: direction['speed'] as String,
          directionTurn: direction['turn'] as int,
          customX: [
            (xPos >> 8) & 0xFF,
            xPos & 0xFF
          ], // Convert to bytes like Swift
          customY: yPos,
        );
        await Future.delayed(const Duration(milliseconds: 8));

        debugPrint(
            'Sent navigation update ${i + 1}: ${direction['direction']} for ${direction['distance']}');
        await Future.delayed(const Duration(seconds: 3));
      }

      // End navigation
      await Future.delayed(const Duration(seconds: 1));
      await bluetoothManager.endNavigation();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Navigation demo completed!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Glasses are not connected')),
      );
    }
  }

  // Generate a simple demo road map (black and white pattern)
  List<bool> _generateDemoRoadMap(int width, int height) {
    final totalPixels = width * height;
    final map = List<bool>.filled(totalPixels, false);

    // Draw simple road pattern (vertical road in middle)
    final roadWidth = width ~/ 4;
    final roadStart = (width - roadWidth) ~/ 2;

    for (int y = 0; y < height; y++) {
      for (int x = roadStart; x < roadStart + roadWidth; x++) {
        map[y * width + x] = true;
      }
      // Add center line
      if (y % 10 < 5) {
        final centerX = width ~/ 2;
        for (int i = -1; i <= 1; i++) {
          if (centerX + i >= 0 && centerX + i < width) {
            map[y * width + centerX + i] = false;
          }
        }
      }
    }

    return map;
  }

  // Generate demo overlay with route line and position marker
  List<bool> _generateDemoOverlay(int width, int height, int step,
      {(int, int)? position}) {
    final totalPixels = width * height;
    final overlay = List<bool>.filled(totalPixels, false);

    // Draw route line (simplified)
    final centerX = width ~/ 2;
    for (int y = 0; y < height; y++) {
      final offset = (step * 5 + y ~/ 10) % 20 - 10;
      final x = centerX + offset;
      if (x >= 0 && x < width) {
        overlay[y * width + x] = true;
        // Make line thicker
        if (x + 1 < width) overlay[y * width + x + 1] = true;
        if (x - 1 >= 0) overlay[y * width + x - 1] = true;
      }
    }

    // Draw position marker if provided (for secondary map)
    if (position != null) {
      final (px, py) = position;
      // Draw a small cross at position
      for (int dy = -3; dy <= 3; dy++) {
        for (int dx = -3; dx <= 3; dx++) {
          if ((dx.abs() <= 1 && dy.abs() <= 3) ||
              (dx.abs() <= 3 && dy.abs() <= 1)) {
            final x = px + dx;
            final y = py + dy;
            if (x >= 0 && x < width && y >= 0 && y < height) {
              overlay[y * width + x] = true;
            }
          }
        }
      }
    }

    return overlay;
  }

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _enableUntestedFeatures =
          prefs.getBool('enable_untested_features') ?? false;
    });
  }

  Future<void> _toggleUntestedFeatures(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enable_untested_features', value);
    setState(() {
      _enableUntestedFeatures = value;
    });
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
          CheckboxListTile(
            title: const Text(
                'Enable untested features that break the design phylosophy'),
            value: _enableUntestedFeatures,
            onChanged: (bool? value) {
              if (value != null) {
                _toggleUntestedFeatures(value);
              }
            },
          ),
          const Divider(),
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
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _debugTranslateCommand,
            child: const Text("Debug Translate"),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _debugNavigationCommand,
            child: const Text("Debug Turn-by-Turn Navigation"),
          ),
        ],
      ),
    );
  }
}
