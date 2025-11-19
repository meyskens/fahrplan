import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_broadcasts/flutter_broadcasts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("BroadcastMessage", () {
    test('toMap returns a map containing a message\'s fields.', () async {
      BroadcastMessage message = BroadcastMessage(name: "message.name.1");
      var map = message.toMap();

      expect(map['name'], equals("message.name.1"));
      expect(map['data'], isNull);
      expect(map['timestamp'], isNotNull);

      final data = <String, dynamic>{
        "a": 1,
        "b": "t",
        "d": <int>[300, 200, 0]
      };
      message = BroadcastMessage(name: "message.name.2", data: data);
      map = message.toMap();

      expect(map['name'], equals("message.name.2"));
      expect(mapEquals(map['data'], data), isTrue);
      expect(map['timestamp'], isNotNull);
    });
  });

  group("BroadcastReceiver", () {
    const MethodChannel channel =
        MethodChannel('de.kevlatus.flutter_broadcasts');

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        switch (methodCall.method) {
          case "startReceiver":
            return null;
          case "stopReceiver":
            return null;
        }
        throw Error();
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test("beforeStart", () async {
      final receiver = BroadcastReceiver(names: <String>["broadcast.name"]);
      expect(receiver.isListening, isFalse);
    });

    test("start", () async {
      final receiver = BroadcastReceiver(names: <String>["broadcast.name"]);
      await receiver.start();
      expect(receiver.isListening, isTrue);

      // expectLater(receiver.messages, emitsInOrder(<Matcher>[isNotNull]));
      // ServicesBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      //   "receiveBroadcast",
      //   const StandardMethodCodec().encodeSuccessEnvelope(
      //     BroadcastMessage(
      //       name: "broadcast.name",
      //       data: {},
      //     ).toMap(),
      //   ),
      //   (ByteData data) {},
      // );
    });

    // test("stop", () {
    //   final receiver = BroadcastReceiver(names: <String>["broadcast.name"]);
    // });

    // test("toMap", () {
    //   final receiver = BroadcastReceiver(names: <String>["broadcast.name"]);
    // });
  });
}
