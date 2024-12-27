import 'package:notification_listener_service/notification_event.dart';
import 'package:notification_listener_service/notification_listener_service.dart';

typedef OnNotification = void Function(ServiceNotificationEvent);

class AndroidNotificationsListener {
  final OnNotification onData;

  AndroidNotificationsListener({required this.onData});

  void startListening() async {
    /// check if notification permession is enebaled
    final bool hasPermission =
        await NotificationListenerService.isPermissionGranted();

    if (!hasPermission) {
      /// request notification permission
      /// it will open the notifications settings page and return `true` once the permission granted.
      await NotificationListenerService.requestPermission();
    }

    /// stream the incoming notification events
    NotificationListenerService.notificationsStream.listen((event) {
      if (event.hasRemoved == null || event.hasRemoved == false) {
        onData(event);
      }
    });
  }
}
