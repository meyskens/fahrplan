import 'package:shared_preferences/shared_preferences.dart';

class WakeWordSettings {
  static const String _accessKeyKey = 'porcupine_access_key';
  static const String _enabledKey = 'wake_word_enabled';

  static Future<String> getAccessKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessKeyKey) ?? "";
  }

  static Future<void> setAccessKey(String accessKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessKeyKey, accessKey);
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
