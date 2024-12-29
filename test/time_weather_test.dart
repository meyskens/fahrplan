import 'package:flutter_test/flutter_test.dart';
import 'package:fahrplan/models/g1/time_weather.dart';
import 'dart:typed_data';

void main() {
  group('TimeAndWeather', () {
    test('getTimestamp32 returns correct 32-bit timestamp', () {
      final timeAndWeather = TimeAndWeather(
        temperatureUnit: TemperatureUnit.CELSIUS,
        timeFormat: TimeFormat.TWENTY_FOUR_HOUR,
        temperatureInCelsius: 20,
        weatherIcon: WeatherIcons.SUNNY,
      );

      final dateTime = DateTime.fromMillisecondsSinceEpoch(1735487311000);
      final expectedTimestamp = Uint8List.fromList([0x4f, 0x6f, 0x71, 0x67]);

      expect(timeAndWeather.getTimestamp32(dateTime), expectedTimestamp);
    });

    test('getTimestamp64 returns correct 64-bit timestamp', () {
      final timeAndWeather = TimeAndWeather(
        temperatureUnit: TemperatureUnit.CELSIUS,
        timeFormat: TimeFormat.TWENTY_FOUR_HOUR,
        temperatureInCelsius: 20,
        weatherIcon: WeatherIcons.SUNNY,
      );

      final dateTime = DateTime.fromMillisecondsSinceEpoch(1735487311000);
      final expectedTimestamp =
          Uint8List.fromList([152, 204, 26, 19, 148, 1, 0, 0]);

      expect(timeAndWeather.getTimestamp64(dateTime), expectedTimestamp);
    });
  });
}
