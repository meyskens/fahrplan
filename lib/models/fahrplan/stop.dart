import 'package:fahrplan/models/fahrplan/fahrplan_dashboard.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'stop.g.dart';

@HiveType(typeId: 1)
class FahrplanStopItem {
  @HiveField(0)
  String title;
  @HiveField(1)
  DateTime time;
  @HiveField(2)
  late String uuid;
  @HiveField(3)
  bool showNotification;

  FahrplanStopItem({
    required this.title,
    required this.time,
    String? uuid,
    this.showNotification = true,
  }) {
    this.uuid = uuid ?? Uuid().v4();
  }

  FahrplanItem toFahrplanItem() {
    return FahrplanItem(
      title: title,
      hour: time.toLocal().hour,
      minute: time.toLocal().minute,
    );
  }

  // Static helper methods for voice commands
  static Future<List<String>> getAllStopTitles() async {
    final box = Hive.lazyBox<FahrplanStopItem>('fahrplanStopBox');
    final List<String> titles = [];
    for (int i = 0; i < box.length; i++) {
      final item = await box.getAt(i);
      if (item != null) {
        titles.add(item.title);
      }
    }
    return titles;
  }

  static Future<FahrplanStopItem?> findStopByTitle(String title) async {
    final box = Hive.lazyBox<FahrplanStopItem>('fahrplanStopBox');
    for (int i = 0; i < box.length; i++) {
      final item = await box.getAt(i);
      if (item != null && item.title.toLowerCase() == title.toLowerCase()) {
        return item;
      }
    }
    return null;
  }

  static Future<bool> deleteStopByTitle(String title) async {
    final box = Hive.lazyBox<FahrplanStopItem>('fahrplanStopBox');
    for (int i = 0; i < box.length; i++) {
      final item = await box.getAt(i);
      if (item != null && item.title.toLowerCase() == title.toLowerCase()) {
        await box.deleteAt(i);
        return true;
      }
    }
    return false;
  }

  static Future<bool> deleteStopByUuid(String uuid) async {
    final box = Hive.lazyBox<FahrplanStopItem>('fahrplanStopBox');
    for (int i = 0; i < box.length; i++) {
      final item = await box.getAt(i);
      if (item != null && item.uuid == uuid) {
        await box.deleteAt(i);
        return true;
      }
    }
    return false;
  }
}
