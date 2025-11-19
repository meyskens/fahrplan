import 'dart:convert';
import 'package:fahrplan/models/android/weather_data.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_broadcasts/flutter_broadcasts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to listen for weather broadcasts from Gadgetbridge-compatible apps
/// and notify listeners about weather updates
class WeatherBroadcastService {
  static const String _actionGenericWeather =
      "nodomain.freeyourgadget.gadgetbridge.ACTION_GENERIC_WEATHER";
  static const String _extraWeatherJson = "WeatherJson";

  BroadcastReceiver? _receiver;
  final List<void Function(WeatherSpec)> _listeners = [];

  /// Register a callback to be notified when weather data is received
  void addListener(void Function(WeatherSpec) listener) {
    _listeners.add(listener);
  }

  /// Remove a previously registered callback
  void removeListener(void Function(WeatherSpec) listener) {
    _listeners.remove(listener);
  }

  /// Start listening for weather broadcasts
  Future<void> start() async {
    if (_receiver != null && _receiver!.isListening) {
      debugPrint('WeatherBroadcastService is already listening');
      return;
    }

    _receiver = BroadcastReceiver(
      names: <String>[_actionGenericWeather],
    );

    _receiver!.messages.listen((BroadcastMessage message) {
      debugPrint('Received weather broadcast: ${message.name}');
      _handleWeatherBroadcast(message);
    });

    await _receiver!.start();
    debugPrint('WeatherBroadcastService started listening for weather updates');
  }

  /// Stop listening for weather broadcasts
  Future<void> stop() async {
    if (_receiver == null || !_receiver!.isListening) {
      return;
    }

    await _receiver!.stop();
    _receiver = null;
    debugPrint('WeatherBroadcastService stopped listening');
  }

  /// Handle incoming weather broadcast
  void _handleWeatherBroadcast(BroadcastMessage message) async {
    try {
      final weatherJson = message.data?[_extraWeatherJson];
      if (weatherJson == null || weatherJson.isEmpty) {
        debugPrint('Weather data is missing in the broadcast');
        return;
      }

      debugPrint('Received weather JSON: $weatherJson');

      // Parse the weather data
      final weatherData = jsonDecode(weatherJson);
      final weatherSpec = WeatherSpec.fromJson(weatherData);

      // Save to shared preferences (same as Kotlin receiver does)
      await _saveWeatherData(weatherJson);

      // Notify all listeners
      for (var listener in _listeners) {
        try {
          listener(weatherSpec);
        } catch (e) {
          debugPrint('Error notifying weather listener: $e');
        }
      }

      debugPrint('Weather data processed and listeners notified');
    } catch (e) {
      debugPrint('Error handling weather broadcast: $e');
    }
  }

  /// Save weather data to shared preferences
  Future<void> _saveWeatherData(String jsonData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('flutter.$_extraWeatherJson', jsonData);
    debugPrint('Weather data saved to shared preferences');
  }

  /// Check if the service is currently listening
  bool get isListening => _receiver?.isListening ?? false;
}
