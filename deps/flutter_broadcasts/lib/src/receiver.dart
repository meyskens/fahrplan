part of 'flutter_broadcasts.dart';

/// Allows for subscribing to [BroadcastMessage]s on the native platform.
///
/// The API is inspired by Android's [BroadcastReceiver](https://developer.android.com/reference/android/content/BroadcastReceiver),
/// since they allow for _bundling_ multiple message types into a single
/// receiver instead of subscribing to them individually.
///
/// On iOS, this uses the [NSNotificationCenter API](https://developer.apple.com/documentation/foundation/notificationcenter).
class BroadcastReceiver {
  static int _index = 0;

  final int _id;
  final StreamController<BroadcastMessage> _messages =
      StreamController<BroadcastMessage>.broadcast();

  /// A list of message names to subscribe to.
  ///
  /// See [BroadcastMessage.name] for more details.
  final List<String> names;

  StreamSubscription? _subscription;

  /// Creates a new [BroadcastReceiver], which subscribes to the given [names].
  ///
  /// At least one name needs to be provided.
  BroadcastReceiver({required this.names})
      : assert(names.isNotEmpty),
        _id = ++_index;

  /// Returns true, if this [BroadcastReceiver] is currently listening for messages.
  bool get isListening => _subscription != null;

  /// A stream of matching messages received from the native platform.
  Stream<BroadcastMessage> get messages => _messages.stream;

  /// Starts listening for messages on this [BroadcastReceiver].
  ///
  /// Throws a [StateError], if it is already listening.
  Future<void> start() async {
    if (isListening) {
      throw StateError('This BroadcastReceiver is already started.');
    }

    final stream = _BroadcastChannel.instance.startReceiver(this);
    _subscription = stream.listen((event) {
      _messages.add(event);
    });
  }

  /// Stops listening for messages on this [BroadcastReceiver], preventing it
  /// from being started again.
  Future<void> stop() async {
    if (!isListening) {
      return;
    }

    await _BroadcastChannel.instance.stopReceiver(this);
    await _subscription!.cancel();
    _subscription = null;
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': _id,
        'names': names,
      };

  @override
  String toString() {
    return toMap().toString();
  }

  @override
  int get hashCode =>
      _id.hashCode ^
      names.hashCode ^
      _subscription.hashCode ^
      _messages.hashCode;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BroadcastReceiver &&
            other._id == _id &&
            other.names == names &&
            other._messages == _messages &&
            other._subscription == _subscription;
  }
}
