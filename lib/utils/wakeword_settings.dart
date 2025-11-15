import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum WakeWordEngine {
  porcupine,
  snowboy,
}

class WakeWordSettings {
  static const String _accessKeyDebugKey = 'porcupine_access_key_debug';
  static const String _accessKeyReleaseKey = 'porcupine_access_key_release';
  static const String _enabledKey = 'wake_word_enabled';
  static const String _engineKey = 'wake_word_engine';
  static const String _snowboyModelKey = 'snowboy_model';

  // Available Snowboy models
  static const Map<String, String> snowboyModels = {
    'snowboy.umdl': 'Snowboy (Default)',
    'hey_extreme.umdl': 'Hey Extreme',
    'neoya.umdl': 'Neoya',
    'smart_mirror.umdl': 'Smart Mirror',
    'subex.umdl': 'Subex',
    'view_glass.umdl': 'View Glass',
  };

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
    final isEnabled = prefs.getBool(_enabledKey) ?? false;

    if (!isEnabled) {
      return false;
    }

    // Check engine-specific requirements
    final engine = await getEngine();
    if (engine == WakeWordEngine.porcupine) {
      // Porcupine requires an access key
      final accessKey = await getAccessKey();
      return accessKey.isNotEmpty;
    } else {
      // Snowboy doesn't require an access key
      return true;
    }
  }

  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
  }

  static Future<WakeWordEngine> getEngine() async {
    final prefs = await SharedPreferences.getInstance();
    final engineString = prefs.getString(_engineKey) ?? 'snowboy';
    return engineString == 'snowboy'
        ? WakeWordEngine.snowboy
        : WakeWordEngine.porcupine;
  }

  static Future<void> setEngine(WakeWordEngine engine) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_engineKey, engine.toString().split('.').last);
  }

  static Future<String> getSnowboyModel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_snowboyModelKey) ?? 'snowboy.umdl';
  }

  static Future<void> setSnowboyModel(String modelFileName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_snowboyModelKey, modelFileName);
  }
}
