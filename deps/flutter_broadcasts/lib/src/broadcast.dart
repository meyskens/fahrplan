part of 'flutter_broadcasts.dart';

/// A message, which is sent by or to the native broadcast system.
///
/// It must have a [name] and may optionally contain a [Map] of user-provided
/// [data].
class BroadcastMessage {
  /// The [BroadcastReceiver._id] of the [BroadcastReceiver], which is
  /// subscribing to messages of this type.
  final int? _receiverId;

  /// A name, which specifies the type of this message.
  ///
  /// On Android, the [name] is retrieved from [Intent.getAction](https://developer.android.com/reference/android/content/Intent#getAction())
  /// and subscribed to using [IntentFilter.addAction](https://developer.android.com/reference/android/content/IntentFilter#addAction(java.lang.String)).
  ///
  /// On iOS, the [name] is retrieved from [NSNotification.name](https://developer.apple.com/documentation/foundation/nsnotification/1416472-name)
  /// and subscribed to using [NotificationCenter.addObserver](https://developer.apple.com/documentation/foundation/notificationcenter/1411723-addobserver).
  final String name;

  /// Optional user-provided data for this message.
  ///
  /// On Android, [data] is retrieved from [Intent.getExtras](https://developer.android.com/reference/android/content/Intent#getExtras())
  /// and sent using [Intent.putExtra](https://developer.android.com/reference/android/content/Intent#putExtra(java.lang.String,%20android.os.Parcelable)).
  ///
  /// On iOS, [data] is retrieved from [NSNotification.userInfo](https://developer.apple.com/documentation/foundation/nsnotification/1409222-userinfo)
  /// and sent using the same property.
  final Map<String, dynamic>? data;

  /// The timestamp when this message was sent or retrieved.
  ///
  /// For incoming messages from a [BroadcastReceiver], this corresponds to the
  /// time at which a message was received.
  ///
  /// For outgoing messages, this is set during [sendBroadcast]. If the
  /// receiver of the sent message also uses this package, the _send_ timestamp
  /// is available in [data] and the _receive_ timestamp is set to this
  /// field.
  ///
  /// The reason for this is that neither Android, nor iOS provide a
  /// standardized way for message timestamps. Therefore, the described logic
  /// tries its best to record consistent timestamps. If you rely on this
  /// information, you should also check the docs for the messages you receive
  /// for hints about timestamps.
  final DateTime? timestamp;

  /// Creates a new [BroadcastMessage], which can be sent using [sendBroadcast].
  BroadcastMessage({
    required this.name,
    this.data,
  })  : timestamp = DateTime.now(),
        _receiverId = null;

  BroadcastMessage._fromMap(Map<dynamic, dynamic> map)
      : _receiverId = map['receiverId'],
        name = map['name'],
        data = map['data'].cast<String, dynamic>(),
        timestamp = map.containsKey('timestamp')
            ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'])
            : null;

  /// Creates a [Map] containing all information about this message.
  Map<String, dynamic> toMap() => <String, dynamic>{
        'receiverId': _receiverId,
        'name': name,
        'data': data,
        'timestamp': timestamp?.toIso8601String(),
      };

  @override
  String toString() {
    return toMap().toString();
  }

  @override
  int get hashCode =>
      _receiverId.hashCode ^ name.hashCode ^ data.hashCode ^ timestamp.hashCode;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BroadcastMessage &&
            _receiverId == other._receiverId &&
            name == other.name &&
            data == other.data &&
            timestamp == other.timestamp;
  }
}

Future<void> sendBroadcast(BroadcastMessage message) {
  return _BroadcastChannel.instance.sendBroadcast(message);
}
