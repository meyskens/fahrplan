import 'dart:async';
import 'dart:math';

import 'package:fahrplan/models/fahrplan/stop.dart';
import 'package:fahrplan/services/bluetooth_manager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive/hive.dart';

class StopsManager {
  static final StopsManager _singleton = StopsManager._internal();
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  factory StopsManager() {
    return _singleton;
  }

  StopsManager._internal();

  List<Timer> timers = [];
  FahrplanStopItem? currentlyTriggeringStop;

  void reload() async {
    cancelTimers();
    await loadStops();
  }

  Future<bool> _isStopStillInDatabase(FahrplanStopItem stop) async {
    final box = Hive.lazyBox<FahrplanStopItem>('fahrplanStopBox');
    for (int i = 0; i < box.length; i++) {
      final item = await box.getAt(i);
      if (item != null && item.uuid == stop.uuid) {
        return true;
      }
    }
    return false;
  }

  Future<void> loadStops() async {
    // Load stops from Hive
    final box = Hive.lazyBox<FahrplanStopItem>('fahrplanStopBox');
    final stops = <FahrplanStopItem>[];
    for (int i = 0; i < box.length; i++) {
      final item = await box.getAt(i);
      if (item != null) {
        stops.add(item);
      }
    }

    // set a timer for each stop
    for (final stop in stops) {
      final timer = Timer(stop.time.difference(DateTime.now()), () {
        _triggerTimer(stop);
      });
      timers.add(timer);
    }
  }

  void _triggerTimer(FahrplanStopItem item) async {
    if (!await _isStopStillInDatabase(item)) {
      return;
    }
    currentlyTriggeringStop = item;
    final bl = BluetoothManager();
    if (bl.isConnected) {
      bl.sendText(item.title, delay: const Duration(seconds: 10));
    }
    // retrigger myself in 10 seconds
    final timer = Timer(const Duration(seconds: 10), () {
      _triggerTimer(item);
    });
    timers.add(timer);

    // show notification
    if (!item.showNotification) {
      return;
    }
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
