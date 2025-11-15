import 'package:device_calendar/device_calendar.dart';
import 'package:fahrplan/models/fahrplan/fahrplan_dashboard.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:flutter_native_timezone_latest/flutter_native_timezone_latest.dart';

part 'calendar.g.dart';

@HiveType(typeId: 2)
class FahrplanCalendar {
  @HiveField(0)
  String id;
  @HiveField(1)
  bool enabled;

  FahrplanCalendar({
    required this.id,
    required this.enabled,
  });
}

class FahrplanCalendarComposer {
  final calendarBox = Hive.box<FahrplanCalendar>('fahrplanCalendarBox');

  Future<List<FahrplanItem>> toFahrplanItems() async {
    final deviceCal = DeviceCalendarPlugin();
    final fpCals = calendarBox.values.toList();

    Location currentLocation = getLocation('Etc/UTC');
    String timezone = 'Etc/UTC';
    try {
      timezone = await FlutterNativeTimezoneLatest.getLocalTimezone();
    } catch (e) {
      debugPrint('Could not get the local timezone');
    }
    currentLocation = getLocation(timezone);
    setLocalLocation(currentLocation);

    final items = <FahrplanItem>[];

    for (var cal in fpCals) {
      if (!cal.enabled) {
        continue;
      }

      final events = await deviceCal.retrieveEvents(
          cal.id,
          RetrieveEventsParams(
            startDate: DateTime.now().toLocal(),
            endDate: DateTime.now().toLocal().add(const Duration(days: 1)),
          ));

      for (Event event in events.data ?? []) {
        if (event.start == null) {
          continue;
        }
        if (!_isToday(event.start!)) {
          continue;
        }

        final start = event.start!;
        items.add(FahrplanItem(
          title: event.title ?? 'No Title',
          hour: start.toLocal().hour,
          minute: start.toLocal().minute,
        ));
      }
    }

    return items;
  }

  bool _isToday(DateTime time) {
    time = time.toLocal();
    final now = DateTime.now().toLocal();
    return time.year == now.year &&
        time.month == now.month &&
        time.day == now.day;
  }
}
