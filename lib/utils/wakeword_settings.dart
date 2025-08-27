import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WakeWordSettings {
  static const String _accessKeyDebugKey = 'porcupine_access_key_debug';
  static const String _accessKeyReleaseKey = 'porcupine_access_key_release';
  static const String _enabledKey = 'wake_word_enabled';

  static Future<String> getAccessKey() async {
    final prefs = await SharedPreferences.getInstance();
    if (kDebugMode) {
      return prefs.getString(_accessKeyDebugKey) ?? "";
    } else {
      return prefs.getString(_accessKeyReleaseKey) ?? "";
    }
  }

  static Future<String> getDebugAccessKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessKeyDebugKey) ?? "";
  }

  static Future<String> getReleaseAccessKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessKeyReleaseKey) ?? "";
  }

  static Future<void> setAccessKey(String accessKey) async {
    final prefs = await SharedPreferences.getInstance();
    if (kDebugMode) {
      await prefs.setString(_accessKeyDebugKey, accessKey);
    } else {
      await prefs.setString(_accessKeyReleaseKey, accessKey);
    }
  }

  static Future<void> setDebugAccessKey(String accessKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessKeyDebugKey, accessKey);
  }

  static Future<void> setReleaseAccessKey(String accessKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessKeyReleaseKey, accessKey);
  }

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    final accessKey = await getAccessKey();
    final isEnabled = prefs.getBool(_enabledKey) ?? false;
    // Only return true if enabled AND there's an access key
    return isEnabled && accessKey.isNotEmpty;
  }

  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
  }
}
