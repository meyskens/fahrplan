import 'package:flutter/foundation.dart';

class WeatherIcons {
  static const int NOTHING = 0x00;
  static const int NIGHT = 0x01;
  static const int CLOUDS = 0x02;
  static const int DRIZZLE = 0x03;
  static const int HEAVY_DRIZZLE = 0x04;
  static const int RAIN = 0x05;
  static const int HEAVY_RAIN = 0x06;
  static const int THUNDER = 0x07;
  static const int THUNDERSTORM = 0x08;
  static const int SNOW = 0x09;
  static const int MIST = 0x0A;
  static const int FOG = 0x0B;
  static const int SAND = 0x0C;
  static const int SQUALLS = 0x0D;
  static const int TORNADO = 0x0E;
  static const int FREEZING_RAIN = 0x0F;
  static const int SUNNY = 0x10;

  static int fromOpenWeatherMapConditionCode(int owpCode) {
    switch (owpCode) {
      case 200:
        return WeatherIcons.THUNDER;
      case 201:
        return WeatherIcons.THUNDERSTORM;
      case 202:
        return WeatherIcons.THUNDERSTORM;
      case 210:
        return WeatherIcons.THUNDERSTORM;
      case 211:
        return WeatherIcons.THUNDERSTORM;
      case 212:
        return WeatherIcons.THUNDERSTORM;
      case 221:
        return WeatherIcons.THUNDERSTORM;
      case 230:
        return WeatherIcons.THUNDERSTORM;
      case 231:
        return WeatherIcons.THUNDERSTORM;
      case 232:
        return WeatherIcons.THUNDERSTORM;
      case 300:
        return WeatherIcons.DRIZZLE;
      case 301:
        return WeatherIcons.DRIZZLE;
      case 302:
        return WeatherIcons.HEAVY_DRIZZLE;
      case 310:
        return WeatherIcons.DRIZZLE;
      case 311:
        return WeatherIcons.DRIZZLE;
      case 312:
        return WeatherIcons.HEAVY_DRIZZLE;
      case 313:
        return WeatherIcons.DRIZZLE;
      case 314:
        return WeatherIcons.HEAVY_DRIZZLE;
      case 321:
        return WeatherIcons.DRIZZLE;
      case 500:
        return WeatherIcons.RAIN;
      case 501:
        return WeatherIcons.RAIN;
      case 502:
        return WeatherIcons.HEAVY_RAIN;
      case 503:
        return WeatherIcons.HEAVY_RAIN;
      case 504:
        return WeatherIcons.HEAVY_RAIN;
      case 511:
        return WeatherIcons.FREEZING_RAIN;
      case 520:
        return WeatherIcons.FREEZING_RAIN;
      case 521:
        return WeatherIcons.HEAVY_RAIN;
      case 522:
        return WeatherIcons.HEAVY_RAIN;
      case 531:
        return WeatherIcons.RAIN;
      case 600:
        return WeatherIcons.SNOW;
      case 601:
        return WeatherIcons.SNOW;
      case 602:
        return WeatherIcons.SNOW;
      case 611:
        return WeatherIcons.SNOW;
      case 612:
        return WeatherIcons.SNOW;
      case 613:
        return WeatherIcons.SNOW;
      case 615:
        return WeatherIcons.SNOW;
      case 616:
        return WeatherIcons.SNOW;
      case 620:
        return WeatherIcons.SNOW;
      case 621:
        return WeatherIcons.SNOW;
      case 622:
        return WeatherIcons.SNOW;
      case 701:
        return WeatherIcons.MIST;
      case 711:
        return WeatherIcons.MIST;
      case 721:
        return WeatherIcons.MIST;
      case 731:
        return WeatherIcons.MIST;
      case 741:
        return WeatherIcons.FOG;
      case 751:
        return WeatherIcons.SAND;
      case 761:
        return WeatherIcons.SAND;
      case 762:
        return WeatherIcons.SAND;
      case 771:
        return WeatherIcons.SQUALLS;
      case 781:
        return WeatherIcons.TORNADO;
      case 800:
        return WeatherIcons.SUNNY;
      case 801:
        return WeatherIcons.SUNNY;
      case 802:
        return WeatherIcons.CLOUDS;
      case 803:
        return WeatherIcons.CLOUDS;
      case 804:
        return WeatherIcons.CLOUDS;
      default: // unknown
        return WeatherIcons.NOTHING;
    }
  }
}

enum TemperatureUnit { CELSIUS, FAHRENHEIT }

enum TimeFormat { TWELVE_HOUR, TWENTY_FOUR_HOUR }

class TimeAndWeather {
  final TemperatureUnit temperatureUnit;
  final TimeFormat timeFormat;

  final int temperatureInCelsius;
  final int weatherIcon;

  TimeAndWeather({
    required this.temperatureUnit,
    required this.timeFormat,
    required this.temperatureInCelsius,
    required this.weatherIcon,
  });

  Uint8List buildAddCommand(int seqId) {
    int convertToFahrenheit =
        temperatureUnit == TemperatureUnit.FAHRENHEIT ? 0x01 : 0x00;
    int is12hFormat = timeFormat == TimeFormat.TWELVE_HOUR ? 0x01 : 0x00;

    final now = DateTime.now();
    final list = Uint8List.fromList([
      0x06, // dashboard command
      0x15, 0x00, // 0x0015 total length of packet
      seqId, // sequence number
      0x01, // 0x01 = (subcommand) update time and weather
      ...getTimestamp32(now), // 32bit timestamp, eg: 0x67716F4F
      ...getTimestamp64(now), // 64bit timestamp, eg: 0x194131ACC98
      //0x4f, 0x6f, 0x71, 0x67, //# 32bit timestamp, eg: 0x67716F4F
      //0x98, 0xc9, 0xac, 0x31, 0x41, 0x19, 0x00,
      //0x00, //# 64bit timestamp, eg: 0x194131ACC98
      weatherIcon, // 0x00 - 0x10, see WeatherIcons
      temperatureInCelsius,
      convertToFahrenheit, // 0x00 or 0x01
      is12hFormat, // 0x00 or 0x01
    ]);

    debugPrint(
        'TimeAndWeather.buildAddCommand: ${list.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');

    debugPrint('TimeAndWeather.buildAddCommand: ${list.length}');
    return list;
  }

  int _getTimezoneOffsetInSeconds() {
    return DateTime.now().timeZoneOffset.inSeconds;
  }

  Uint8List getTimestamp32(DateTime time) {
    debugPrint(_getTimezoneOffsetInSeconds().toString());
    final timestamp = time
            .add(Duration(seconds: _getTimezoneOffsetInSeconds()))
            .millisecondsSinceEpoch ~/
        1000;

    final Uint8List timestampBytes = Uint8List(4)
      ..buffer.asByteData().setUint32(0, timestamp, Endian.little);
    return timestampBytes;
  }

  Uint8List getTimestamp64(DateTime time) {
    final timestamp = time
        .add(Duration(seconds: _getTimezoneOffsetInSeconds()))
        .millisecondsSinceEpoch;

    final Uint8List timestampBytes = Uint8List(8)
      ..buffer.asByteData().setUint64(0, timestamp, Endian.little);
    return timestampBytes;
  }
}
