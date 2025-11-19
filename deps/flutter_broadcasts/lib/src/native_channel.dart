part of 'flutter_broadcasts.dart';

/// Listens for [BroadcastMessages]s on the given [channel].
///
/// This listens for calls to 'receiveBroadcast' using
/// [MethodChannel.setMethodCallHandler] and feeds all invocations into a
/// [StreamController]. When there is no listener on the returned stream,
/// listening on the [channel] is also paused.
Stream<BroadcastMessage> _listenForBroadcasts(MethodChannel channel) {
  // ignore: close_sinks
  StreamController<BroadcastMessage>? controller;

  void startListening() {
    channel.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'receiveBroadcast') {
        final message = BroadcastMessage._fromMap(call.arguments);
        controller?.add(message);
      }
    });
  }

  void stopListening() {
    channel.setMethodCallHandler(null);
  }

  controller = StreamController<BroadcastMessage>.broadcast(
    onListen: startListening,
    onCancel: stopListening,
  );

  return controller.stream;
}

/// An internal singleton for managing the communication to the native platform.
///
/// Since identically named [MethodChannel]s interfere with each other, this
/// singleton handles all communication to the platform and forwards messages to
/// the appropriate [BroadcastReceiver].
class _BroadcastChannel {
  static const MethodChannel _channel =
      MethodChannel('de.kevlatus.flutter_broadcasts');
  static _BroadcastChannel instance = _BroadcastChannel();

  /// A permanent stream of [BroadcastMessage]s from the native platform.
  ///
  /// See: [_listenForBroadcasts]
  final Stream<BroadcastMessage> _messages = _listenForBroadcasts(_channel);

  Stream<BroadcastMessage> startReceiver(BroadcastReceiver receiver) async* {
    final String? result =
        await _channel.invokeMethod('startReceiver', receiver.toMap());

    if (result != null) {
      throw FlutterError(result);
    }

    yield* _messages.where((event) => receiver._id == event._receiverId);
  }

  /// Stops listening on a given [BroadcastReceiver].
  Future<void> stopReceiver(BroadcastReceiver receiver) async {
    final String? result =
        await _channel.invokeMethod('stopReceiver', receiver.toMap());

    if (result != null) {
      throw FlutterError(result);
    }
  }

  /// Sends the given broadcast [message] natively.
  Future<void> sendBroadcast(BroadcastMessage message) async {
    final String? result = await _channel.invokeMethod(
      "sendBroadcast",
      message.toMap(),
    );

    if (result != null) {
      throw FlutterError(result);
    }
  }
}
