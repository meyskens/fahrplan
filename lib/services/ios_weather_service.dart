import 'dart:convert';
import 'dart:io';

import 'package:fahrplan/models/android/weather_data.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to fetch weather data using WeatherKit on iOS
/// This provides native iOS weather integration as an alternative to
/// the Android Gadgetbridge weather broadcast approach
class IosWeatherService {
  static const String _sharedPrefsKey = 'WeatherJson';
  static const MethodChannel _channel = MethodChannel('dev.maartje.fahrplan/weather');

  final List<void Function(WeatherSpec)> _listeners = [];
  bool _isStarted = false;

  /// Register a callback to be notified when weather data is received
  void addListener(void Function(WeatherSpec) listener) {
    _listeners.add(listener);
  }

  /// Remove a previously registered callback
  void removeListener(void Function(WeatherSpec) listener) {
    _listeners.remove(listener);
  }

  /// Start listening for weather updates from WeatherKit
  Future<void> start() async {
    if (!Platform.isIOS) {
      debugPrint('IosWeatherService is only available on iOS');
      return;
    }

    if (_isStarted) {
      debugPrint('IosWeatherService is already started');
      return;
    }

    // Set up method call handler for weather updates from native side
    _channel.setMethodCallHandler(_handleMethodCall);

    try {
      await _channel.invokeMethod('startWeatherUpdates');
      _isStarted = true;
      debugPrint('IosWeatherService started');
    } catch (e) {
      debugPrint('Failed to start IosWeatherService: $e');
      throw e;
    }
  }

  /// Stop listening for weather updates
  Future<void> stop() async {
    if (!Platform.isIOS) {
      return;
    }

    if (!_isStarted) {
      return;
    }

    try {
      await _channel.invokeMethod('stopWeatherUpdates');
      _isStarted = false;
      _channel.setMethodCallHandler(null);
      debugPrint('IosWeatherService stopped');
    } catch (e) {
      debugPrint('Error stopping IosWeatherService: $e');
    }
  }

  /// Get current weather data (cached or fresh)
  Future<WeatherSpec?> getCurrentWeather() async {
    if (!Platform.isIOS) {
      return null;
    }

    // First check shared preferences for cached data
    final cached = await _getCachedWeather();
    if (cached != null) {
      return cached;
    }

    // Otherwise fetch from native side
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getCurrentWeather');
      if (result != null) {
        final weatherData = Map<String, dynamic>.from(result);
        await _saveWeatherData(weatherData);
        return WeatherSpec.fromJson(weatherData);
      }
    } catch (e) {
      debugPrint('Error getting current weather: $e');
    }

    return null;
  }

  /// Handle method calls from native iOS side
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onWeatherUpdate':
        _handleWeatherUpdate(call.arguments as Map<dynamic, dynamic>);
        break;
      default:
        debugPrint('Unknown method call: ${call.method}');
    }
  }

  /// Handle weather update from native iOS side
  void _handleWeatherUpdate(Map<dynamic, dynamic> arguments) async {
    try {
      final weatherData = Map<String, dynamic>.from(arguments);
      await _saveWeatherData(weatherData);

      final weatherSpec = WeatherSpec.fromJson(weatherData);

      // Notify all listeners
      for (var listener in _listeners) {
        try {
          listener(weatherSpec);
        } catch (e) {
          debugPrint('Error notifying weather listener: $e');
        }
      }

      debugPrint('Weather updated via WeatherKit: ${weatherSpec.location} ${weatherSpec.currentTemp}K');
    } catch (e) {
      debugPrint('Error handling weather update: $e');
    }
  }

  /// Save weather data to shared preferences
  Future<void> _saveWeatherData(Map<String, dynamic> weatherData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sharedPrefsKey, jsonEncode(weatherData));
  }

  /// Get cached weather data from shared preferences
  Future<WeatherSpec?> _getCachedWeather() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_sharedPrefsKey);
    if (json == null) {
      return null;
    }
    try {
      return WeatherSpec.fromJson(jsonDecode(json));
    } catch (e) {
      debugPrint('Error parsing cached weather: $e');
      return null;
    }
  }

  /// Check if the service is currently running
  bool get isStarted => _isStarted;
}
