import 'dart:async';

import 'package:fahrplan/models/fahrplan/daily.dart';
import 'package:fahrplan/models/fahrplan/stop.dart';
import 'package:fahrplan/services/bluetooth_manager.dart';
import 'package:fahrplan/services/stops_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'screens/home_screen.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  flutterLocalNotificationsPlugin.initialize(
    InitializationSettings(
      android: AndroidInitializationSettings('branding'),
    ),
    onDidReceiveNotificationResponse: (NotificationResponse resp) async {
      debugPrint('onDidReceiveBackgroundNotificationResponse: $resp');
      if (resp.actionId == null) {
        return;
      }
      if (resp.actionId!.startsWith("delete_")) {
        _handleDeleteAction(resp.actionId!);
      }
    },
    onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
  );

  await _initHive();

  await initializeService();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: HomePage(),
    );
  }
}

Future<void> _initHive() async {
  Hive.registerAdapter(FahrplanDailyItemAdapter());
  Hive.registerAdapter(FahrplanStopItemAdapter());
  await Hive.initFlutter();
  await Hive.openBox<FahrplanDailyItem>('fahrplanDailyBox');
  await Hive.openBox<FahrplanStopItem>('fahrplanStopBox');
}

// this will be used as notification channel id
const notificationChannelId = 'my_foreground';

// this will be used for notification id, So you can update your custom notification with this id.
const notificationId = 888;

Future<void> initializeService() async {
  flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();

  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    notificationChannelId, // id
    'Fahrplan', // title
    description:
        'This channel is used for Fahrplan notifications.', // description
    importance: Importance.low, // importance must be at low or higher level
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      // this will be executed when app is in foreground or background in separated isolate
      onStart: onStart,

      // auto start service
      autoStart: true,
      isForegroundMode: true,

      notificationChannelId:
          notificationChannelId, // this must match with notification channel you created above.
      initialNotificationTitle: 'Fahrplan',
      initialNotificationContent: 'Initializing',
      foregroundServiceNotificationId: notificationId,

      autoStartOnBoot: true,
    ),
    iosConfiguration: IosConfiguration(),
  );
}

@pragma('vm:entry-point')
Future<void> onStart(ServiceInstance service) async {
  // Only available for flutter 3.0.0 and later
  //DartPluginRegistrant.ensureInitialized();

  try {
    await Hive.initFlutter();
    _initHive();
  } catch (e) {
    debugPrint('Hive already initialized');
  }

  if (!Hive.isBoxOpen('fahrplanDailyBox')) {
    await Hive.openBox<FahrplanDailyItem>('fahrplanDailyBox');
  }
  if (!Hive.isBoxOpen('fahrplanStopBox')) {
    await Hive.openBox<FahrplanStopItem>('fahrplanStopBox');
  }

  BluetoothManager(); // initialize bluetooth manager singleton
  StopsManager().reload(); // initialize bluetooth manager singleton

  // bring to foreground
  Timer.periodic(const Duration(seconds: 30), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        flutterLocalNotificationsPlugin.show(
          notificationId,
          'Fahrplan',
          'Awesome ${DateTime.now()}',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              notificationChannelId,
              'MY FOREGROUND SERVICE',
              icon: 'branding',
              ongoing: true,
            ),
          ),
        );
      }
    }
  });
}

void startBackgroundService() {
  final service = FlutterBackgroundService();
  service.startService();
}

void stopBackgroundService() {
  final service = FlutterBackgroundService();
  service.invoke("stop");
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  debugPrint('notificationTapBackground: $notificationResponse');
  if (notificationResponse.actionId == null) {
    return;
  }

  if (notificationResponse.actionId!.startsWith("delete_")) {
    _handleDeleteAction(notificationResponse.actionId!);
  }

  // handle action
}

void _handleDeleteAction(String actionId) async {
  if (actionId.startsWith("delete_")) {
    final id = actionId.split("_")[1];
    await Hive.openBox<FahrplanStopItem>('fahrplanStopBox');
    final box = Hive.box<FahrplanStopItem>('fahrplanStopBox');
    debugPrint('Deleting item with id: $id');
    for (var i = 0; i < box.length; i++) {
      final item = box.getAt(i);
      if (item!.uuid == id) {
        debugPrint('Deleting item: $i');
        await box.deleteAt(i);
        break;
      }
    }
    StopsManager().reload();
  }
}
