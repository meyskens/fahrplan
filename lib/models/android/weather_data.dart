// we use https://gadgetbridge.org/internals/development/weather-support/ to get the weather data
// suggested app is Breezy Weather
// this is received in Kotlin code and saved into shared preferences

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class WeatherProvider {
  static const String _sharedPrefsKey = 'WeatherJson';

  static Future<WeatherSpec?> getWeather() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_sharedPrefsKey);
    if (json == null) {
      return null;
    }
    return WeatherSpec.fromJson(jsonDecode(json));
  }
}

class WeatherSpec {
  static const int VERSION = 4;

  int? timestamp; // unix epoch timestamp, in seconds
  String? location;
  int? currentTemp; // kelvin
  int? currentConditionCode; // OpenWeatherMap condition code
  String? currentCondition;
  int? currentHumidity;
  int? todayMaxTemp; // kelvin
  int? todayMinTemp; // kelvin
  double? windSpeed; // km per hour
  int? windDirection; // deg
  double? uvIndex; // 0.0 to 15.0
  int? precipProbability; // %
  int? dewPoint; // kelvin
  double? pressure; // mb
  int? cloudCover; // %
  int? moonSet; // unix epoch timestamp, in seconds
  int? moonPhase; // deg [0, 360[
  double? latitude;
  double? longitude;
  int? feelsLikeTemp; // kelvin
  int? isCurrentLocation; // 0 for false, 1 for true, -1 for unknown
  AirQuality? airQuality;
  List<Daily>? forecasts;
  List<Hourly>? hourly;

  WeatherSpec({
    this.timestamp,
    this.location,
    this.currentTemp,
    this.currentConditionCode,
    this.currentCondition,
    this.currentHumidity,
    this.todayMaxTemp,
    this.todayMinTemp,
    this.windSpeed,
    this.windDirection,
    this.uvIndex,
    this.precipProbability,
    this.dewPoint,
    this.pressure,
    this.cloudCover,
    this.moonSet,
    this.moonPhase,
    this.latitude,
    this.longitude,
    this.feelsLikeTemp,
    this.isCurrentLocation,
    this.airQuality,
    this.forecasts,
    this.hourly,
  });

  factory WeatherSpec.fromJson(Map<String, dynamic> json) {
    return WeatherSpec(
      timestamp: json['timestamp'],
      location: json['location'],
      currentTemp: json['currentTemp'],
      currentConditionCode: json['currentConditionCode'],
      currentCondition: json['currentCondition'],
      currentHumidity: json['currentHumidity'],
      todayMaxTemp: json['todayMaxTemp'],
      todayMinTemp: json['todayMinTemp'],
      windSpeed: json['windSpeed'],
      windDirection: json['windDirection'],
      uvIndex: json['uvIndex'],
      precipProbability: json['precipProbability'],
      dewPoint: json['dewPoint'],
      pressure: json['pressure'],
      cloudCover: json['cloudCover'],
      moonSet: json['moonSet'],
      moonPhase: json['moonPhase'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      feelsLikeTemp: json['feelsLikeTemp'],
      isCurrentLocation: json['isCurrentLocation'],
      airQuality: json['airQuality'] != null
          ? AirQuality.fromJson(json['airQuality'])
          : null,
      forecasts: json['forecasts'] != null
          ? (json['forecasts'] as List).map((i) => Daily.fromJson(i)).toList()
          : null,
      hourly: json['hourly'] != null
          ? (json['hourly'] as List).map((i) => Hourly.fromJson(i)).toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp,
      'location': location,
      'currentTemp': currentTemp,
      'currentConditionCode': currentConditionCode,
      'currentCondition': currentCondition,
      'currentHumidity': currentHumidity,
      'todayMaxTemp': todayMaxTemp,
      'todayMinTemp': todayMinTemp,
      'windSpeed': windSpeed,
      'windDirection': windDirection,
      'uvIndex': uvIndex,
      'precipProbability': precipProbability,
      'dewPoint': dewPoint,
      'pressure': pressure,
      'cloudCover': cloudCover,
      'moonSet': moonSet,
      'moonPhase': moonPhase,
      'latitude': latitude,
      'longitude': longitude,
      'feelsLikeTemp': feelsLikeTemp,
      'isCurrentLocation': isCurrentLocation,
      'airQuality': airQuality?.toJson(),
      'forecasts': forecasts?.map((i) => i.toJson()).toList(),
      'hourly': hourly?.map((i) => i.toJson()).toList(),
    };
  }
}

class AirQuality {
  int? aqi; // Air Quality Index
  double? co; // Carbon Monoxide, mg/m^3
  double? no2; // Nitrogen Dioxide, ug/m^3
  double? o3; // Ozone, ug/m^3
  double? pm10; // Particulate Matter, 10 microns or less in diameter, ug/m^3
  double? pm25; // Particulate Matter, 2.5 microns or less in diameter, ug/m^3
  double? so2; // Sulphur Dioxide, ug/m^3
  int? coAqi;
  int? no2Aqi;
  int? o3Aqi;
  int? pm10Aqi;
  int? pm25Aqi;
  int? so2Aqi;

  AirQuality({
    this.aqi,
    this.co,
    this.no2,
    this.o3,
    this.pm10,
    this.pm25,
    this.so2,
    this.coAqi,
    this.no2Aqi,
    this.o3Aqi,
    this.pm10Aqi,
    this.pm25Aqi,
    this.so2Aqi,
  });

  factory AirQuality.fromJson(Map<String, dynamic> json) {
    return AirQuality(
      aqi: json['aqi'],
      co: json['co'],
      no2: json['no2'],
      o3: json['o3'],
      pm10: json['pm10'],
      pm25: json['pm25'],
      so2: json['so2'],
      coAqi: json['coAqi'],
      no2Aqi: json['no2Aqi'],
      o3Aqi: json['o3Aqi'],
      pm10Aqi: json['pm10Aqi'],
      pm25Aqi: json['pm25Aqi'],
      so2Aqi: json['so2Aqi'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'aqi': aqi,
      'co': co,
      'no2': no2,
      'o3': o3,
      'pm10': pm10,
      'pm25': pm25,
      'so2': so2,
      'coAqi': coAqi,
      'no2Aqi': no2Aqi,
      'o3Aqi': o3Aqi,
      'pm10Aqi': pm10Aqi,
      'pm25Aqi': pm25Aqi,
      'so2Aqi': so2Aqi,
    };
  }
}

class Daily {
  int? minTemp; // Kelvin
  int? maxTemp; // Kelvin
  int? conditionCode; // OpenWeatherMap condition code
  int? humidity;
  double? windSpeed; // km per hour
  int? windDirection; // deg
  double? uvIndex; // 0.0 to 15.0
  int? precipProbability; // %
  int? sunRise;
  int? sunSet;
  int? moonRise;
  int? moonSet;
  int? moonPhase;
  AirQuality? airQuality;

  Daily({
    this.minTemp,
    this.maxTemp,
    this.conditionCode,
    this.humidity,
    this.windSpeed,
    this.windDirection,
    this.uvIndex,
    this.precipProbability,
    this.sunRise,
    this.sunSet,
    this.moonRise,
    this.moonSet,
    this.moonPhase,
    this.airQuality,
  });

  factory Daily.fromJson(Map<String, dynamic> json) {
    return Daily(
      minTemp: json['minTemp'],
      maxTemp: json['maxTemp'],
      conditionCode: json['conditionCode'],
      humidity: json['humidity'],
      windSpeed: json['windSpeed'],
      windDirection: json['windDirection'],
      uvIndex: json['uvIndex'],
      precipProbability: json['precipProbability'],
      sunRise: json['sunRise'],
      sunSet: json['sunSet'],
      moonRise: json['moonRise'],
      moonSet: json['moonSet'],
      moonPhase: json['moonPhase'],
      airQuality: json['airQuality'] != null
          ? AirQuality.fromJson(json['airQuality'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'minTemp': minTemp,
      'maxTemp': maxTemp,
      'conditionCode': conditionCode,
      'humidity': humidity,
      'windSpeed': windSpeed,
      'windDirection': windDirection,
      'uvIndex': uvIndex,
      'precipProbability': precipProbability,
      'sunRise': sunRise,
      'sunSet': sunSet,
      'moonRise': moonRise,
      'moonSet': moonSet,
      'moonPhase': moonPhase,
      'airQuality': airQuality?.toJson(),
    };
  }
}

class Hourly {
  int? timestamp; // unix epoch timestamp, in seconds
  int? temp; // Kelvin
  int? conditionCode; // OpenWeatherMap condition code
  int? humidity;
  double? windSpeed; // km per hour
  int? windDirection; // deg
  double? uvIndex; // 0.0 to 15.0
  int? precipProbability; // %

  Hourly({
    this.timestamp,
    this.temp,
    this.conditionCode,
    this.humidity,
    this.windSpeed,
    this.windDirection,
    this.uvIndex,
    this.precipProbability,
  });

  factory Hourly.fromJson(Map<String, dynamic> json) {
    return Hourly(
      timestamp: json['timestamp'],
      temp: json['temp'],
      conditionCode: json['conditionCode'],
      humidity: json['humidity'],
      windSpeed: json['windSpeed'],
      windDirection: json['windDirection'],
      uvIndex: json['uvIndex'],
      precipProbability: json['precipProbability'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp,
      'temp': temp,
      'conditionCode': conditionCode,
      'humidity': humidity,
      'windSpeed': windSpeed,
      'windDirection': windDirection,
      'uvIndex': uvIndex,
      'precipProbability': precipProbability,
    };
  }
}
