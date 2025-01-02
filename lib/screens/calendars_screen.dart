import 'package:fahrplan/models/fahrplan/calendar.dart';
import 'package:flutter/material.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';

class CalendarsPage extends StatefulWidget {
  const CalendarsPage({super.key});

  @override
  CalendarsPageState createState() {
    return CalendarsPageState();
  }
}

class CalendarsPageState extends State<CalendarsPage> {
  final List<Calendar> _calendars = [];
  late Box<FahrplanCalendar> _calendarBox;

  @override
  void initState() {
    super.initState();
    _calendarBox = Hive.box<FahrplanCalendar>('fahrplanCalendarBox');
    _retrieveCalendars();
  }

  void _retrieveCalendars() async {
    try {
      final deviceCalendarPlugin = DeviceCalendarPlugin();
      final hasPerms = await deviceCalendarPlugin.hasPermissions();

      if (!hasPerms.isSuccess) {
        final permsGranted = await deviceCalendarPlugin.requestPermissions();
        if (permsGranted.isSuccess) {
          debugPrint('Permissions not granted');
          return;
        }
      }

      final calendarsResult = await deviceCalendarPlugin.retrieveCalendars();
      if (calendarsResult.isSuccess && calendarsResult.data != null) {
        setState(() {
          _calendars.clear();
          _calendars.addAll(calendarsResult.data!);
        });
        debugPrint('Calendars retrieved: ${_calendars.length}');
        for (var calendar in _calendars) {
          debugPrint('Calendar: ${calendar.name}, ID: ${calendar.id}');
        }
      } else {
        debugPrint('Failed to retrieve calendars');
      }
    } on PlatformException catch (e) {
      debugPrint('Error retrieving calendars: ${e.toString()}');
    }
  }

  void _toggleCalendar(Calendar calendar) async {
    final boxCals = _calendarBox.values.toList();
    final index = boxCals.indexWhere((c) => c.id == calendar.id);

    if (index == -1) {
      _calendarBox.add(FahrplanCalendar(id: calendar.id!, enabled: true));
    } else {
      final cal = boxCals[index];
      cal.enabled = !cal.enabled;
      await _calendarBox.putAt(index, cal);
    }

    setState(() {});
  }

  Widget _getRefreshButton() {
    return IconButton(
      icon: const Icon(Icons.refresh),
      onPressed: _retrieveCalendars,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendars'),
        actions: [_getRefreshButton()],
      ),
      body: ListView.builder(
        itemCount: _calendars.length,
        itemBuilder: (BuildContext context, int index) {
          final calendar = _calendars[index];
          final isEnabled = _calendarBox.values
              .firstWhere((c) => c.id == calendar.id,
                  orElse: () =>
                      FahrplanCalendar(id: calendar.id!, enabled: false))
              .enabled;

          return ListTile(
            title: Text(calendar.name ?? 'No name'),
            subtitle: Text('ID: ${calendar.id ?? 'No ID'}'),
            trailing: Switch(
              value: isEnabled,
              onChanged: (value) {
                _toggleCalendar(calendar);
              },
            ),
            onTap: () {
              _toggleCalendar(calendar);
            },
          );
        },
      ),
    );
  }
}
