import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:fahrplan/models/android/weather_data.dart';
import 'package:fahrplan/models/fahrplan/stop.dart';
import 'package:fahrplan/models/g1/dashboard.dart';
import 'package:fahrplan/models/g1/time_weather.dart';
import 'package:fahrplan/services/bluetooth_manager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StopsManager {
  static final StopsManager _singleton = StopsManager._internal();
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  factory StopsManager() {
    return _singleton;
  }

  StopsManager._internal();

  List<Timer> timers = [];

  void reload() {
    cancelTimers();
    loadStops();
  }

  bool _isStopStillInDatabase(FahrplanStopItem stop) {
    final box = Hive.box<FahrplanStopItem>('fahrplanStopBox');
    for (final item in box.values) {
      if (item.uuid == stop.uuid) {
        return true;
      }
    }
    return false;
  }

  void loadStops() {
    // Load stops from Hive
    final box = Hive.box<FahrplanStopItem>('fahrplanStopBox');
    final stops = box.values.toList();

    // set a timer for each stop
    for (final stop in stops) {
      final timer = Timer(stop.time.difference(DateTime.now()), () {
        _triggerTimer(stop);
      });
      timers.add(timer);
    }
  }

  void _triggerTimer(FahrplanStopItem item) {
    if (!_isStopStillInDatabase(item)) {
      return;
    }
    final bl = BluetoothManager();
    if (bl.isConnected) {
      bl.sendText(item.title, delay: const Duration(seconds: 10));
    }
    // retrigger myself in 10 seconds
    final timer = Timer(const Duration(seconds: 20), () {
      _triggerTimer(item);
    });
    timers.add(timer);

    // show notification
    flutterLocalNotificationsPlugin.show(
      Random().nextInt(1000),
      'Fahrplan',
      'Time to: ${item.title}',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'fahrplan',
          'Fahrplan',
          icon: 'branding',
          importance: Importance.max,
          priority: Priority.high,
          actions: [
            AndroidNotificationAction('delete_${item.uuid}', 'Delete',
                cancelNotification: true, showsUserInterface: true),
          ],
        ),
      ),
    );
  }

  void cancelTimers() {
    for (final timer in timers) {
      timer.cancel();
    }
    timers.clear();
  }
}
