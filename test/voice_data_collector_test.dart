import 'package:flutter_test/flutter_test.dart';
import 'package:fahrplan/services/bluetooth_reciever.dart';

void main() {
  group('VoiceDataCollector', () {
    test('keeps every packet when the sequence counter wraps', () async {
      final collector = VoiceDataCollector();

      // Three laps of the 0..255 counter, i.e. roughly 77 seconds of speech.
      for (int lap = 0; lap < 3; lap++) {
        for (int seq = 0; seq < 256; seq++) {
          await collector.addChunk(seq, [lap, seq]);
        }
      }

      expect(collector.getAllData().length, 3 * 256 * 2);
    });

    test('keeps packets in the order they were spoken', () async {
      final collector = VoiceDataCollector();
      final expected = <int>[];

      for (int lap = 0; lap < 2; lap++) {
        for (int seq = 0; seq < 256; seq++) {
          await collector.addChunk(seq, [lap, seq]);
          expected.addAll([lap, seq]);
        }
      }

      expect(collector.getAllData(), expected);
    });

    test('reset clears the wrap state', () async {
      final collector = VoiceDataCollector();

      for (int seq = 250; seq < 256; seq++) {
        await collector.addChunk(seq, [seq]);
      }
      collector.reset(skipWakeWordCheck: true);
      await collector.addChunk(0, [42]);

      expect(collector.getAllData(), [42]);
    });
  });
}
