import 'package:device_calendar/device_calendar.dart';
import 'package:fahrplan/models/fahrplan/fahrplan_dashboard.dart';
import 'package:hive/hive.dart';

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

    final items = <FahrplanItem>[];

    for (var cal in fpCals) {
      if (!cal.enabled) {
        continue;
      }

      final events = await deviceCal.retrieveEvents(
          cal.id,
          RetrieveEventsParams(
            startDate: DateTime.now(),
            endDate: DateTime.now().add(const Duration(days: 1)),
          ));

      for (var event in events.data ?? []) {
        if (!_isToday(event.start!)) {
          continue;
        }

        items.add(FahrplanItem(
          title: event.title,
          hour: event.start!.hour,
          minute: event.start!.minute,
        ));
      }
    }

    return items;
  }

  bool _isToday(DateTime time) {
    final now = DateTime.now();
    return time.year == now.year &&
        time.month == now.month &&
        time.day == now.day;
  }
}
