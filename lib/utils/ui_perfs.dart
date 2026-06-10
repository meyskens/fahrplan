import 'package:shared_preferences/shared_preferences.dart';

class UiPerfs {
  static final UiPerfs singleton = UiPerfs._internal();

  factory UiPerfs() {
    return singleton;
  }

  UiPerfs._internal();

  bool _trainNerdMode = false;
  bool get trainNerdMode => _trainNerdMode;
  set trainNerdMode(bool value) => _setTrainNerdMode(value);

  bool _backgroundAudioKeepAlive = false;
  bool get backgroundAudioKeepAlive => _backgroundAudioKeepAlive;
  set backgroundAudioKeepAlive(bool value) =>
      _setBackgroundAudioKeepAlive(value);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _trainNerdMode = prefs.getBool('trainNerdMode') ?? false;
    _backgroundAudioKeepAlive =
        prefs.getBool('backgroundAudioKeepAlive') ?? false;
  }

  void _setTrainNerdMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    _trainNerdMode = value;
    prefs.setBool('trainNerdMode', value);
  }

  void _setBackgroundAudioKeepAlive(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    _backgroundAudioKeepAlive = value;
    prefs.setBool('backgroundAudioKeepAlive', value);
  }
}
