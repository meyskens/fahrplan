[![](https://img.shields.io/pub/v/flutter_broadcasts)](https://pub.dev/packages/flutter_broadcasts)

# Flutter Broadcasts

A plugin for sending and receiving broadcasts with Android intents and iOS notifications. The API is inspired by Android's [BroadcastReceivers](https://developer.android.com/reference/android/content/BroadcastReceiver) and uses the [NotificationCenter](https://developer.apple.com/documentation/foundation/notificationcenter) internally on iOS.

## Quick Start

First install the package via [pub.dev](https://pub.dev/packages/flutter_broadcasts/install). Then subscribe to broadcasts like this:

```dart
BroadcastReceiver receiver = BroadcastReceiver(
  names: <String>["de.kevlatus.broadcast"],
);
receiver.messages.listen(print);
receiver.start();
```

## Roadmap

This package is currently under construction. Below you can find a quick overview of its implementation status. Contributions are welcome, if you are missing features.

- [x] implement broadcast receiver on Android
- [x] implement broadcast sending on Android
- [ ] implement NSNotificationCenter subscriptions on iOS
- [ ] implement NSNotificationCenter notifications on iOS

## Contributions

Contributions are much appreciated, but keep in mind that this package is supposed to be generic and only expose native broadcast APIs like [Android's BroadcastReceivers](https://developer.android.com/reference/android/content/BroadcastReceiver) and the [iOS NotificiationCenter](https://developer.apple.com/documentation/foundation/notificationcenter). Consider creating separate packages for sending and receiving specific broadcast instances.

If you have any ideas for extending this package to other platforms, feel free to
[open a pull request](https://github.com/kevlatus/flutter_broadcasts/pulls) or
[raise an issue](https://github.com/kevlatus/flutter_broadcasts/issues).
