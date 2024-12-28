import 'package:fahrplan/models/fahrplan/fahrplan_dashboard.dart';
import 'package:hive/hive.dart';

part 'daily.g.dart';

@HiveType(typeId: 0)
class FahrplanDailyItem {
  @HiveField(0)
  final String title;
  @HiveField(1)
  final int? hour;
  @HiveField(2)
  final int? minute;

  FahrplanDailyItem({
    required this.title,
    this.hour,
    this.minute,
  });

  FahrplanItem toFahrplanItem() {
    return FahrplanItem(
      title: title,
      hour: hour,
      minute: minute,
    );
  }
}
