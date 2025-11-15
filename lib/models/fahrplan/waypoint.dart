import 'package:fahrplan/models/fahrplan/fahrplan_dashboard.dart';
import 'package:hive/hive.dart';

part 'waypoint.g.dart';

@HiveType(typeId: 6)
class FahrplanWaypoint {
  @HiveField(0)
  String description;
  @HiveField(1)
  DateTime startTime;

  FahrplanWaypoint({
    required this.description,
    required this.startTime,
  });

  FahrplanItem toFahrplanItem() {
    return FahrplanItem(
      title: description,
      hour: startTime.hour,
      minute: startTime.minute,
      showTime: false,
      ignoreTime: true,
    );
  }

  // Static helper methods for voice commands
  static List<String> getAllWaypointDescriptions() {
    final box = Hive.box<FahrplanWaypoint>('fahrplanWaypointBox');
    return box.values.map((w) => w.description).toList();
  }

  static FahrplanWaypoint? findWaypointByDescription(String description) {
    final box = Hive.box<FahrplanWaypoint>('fahrplanWaypointBox');
    try {
      return box.values.firstWhere(
        (w) => w.description.toLowerCase() == description.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  static bool deleteWaypointByDescription(String description) {
    final box = Hive.box<FahrplanWaypoint>('fahrplanWaypointBox');
    for (int i = 0; i < box.length; i++) {
      final waypoint = box.getAt(i);
      if (waypoint != null &&
          waypoint.description.toLowerCase() == description.toLowerCase()) {
        box.deleteAt(i);
        return true;
      }
    }
    return false;
  }

  static bool delayWaypointByDescription(String description) {
    final box = Hive.box<FahrplanWaypoint>('fahrplanWaypointBox');
    for (int i = 0; i < box.length; i++) {
      final waypoint = box.getAt(i);
      if (waypoint != null &&
          waypoint.description.toLowerCase() == description.toLowerCase()) {
        // Delay to tomorrow at the same time
        final tomorrow = waypoint.startTime.add(Duration(days: 1));
        final updatedWaypoint = FahrplanWaypoint(
          description: waypoint.description,
          startTime: tomorrow,
        );
        box.putAt(i, updatedWaypoint);
        return true;
      }
    }
    return false;
  }
}
