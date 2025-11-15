import 'package:fahrplan/services/bluetooth_manager.dart';
import 'package:fahrplan/voice/module.dart';
import 'package:flutter_media_controller/flutter_media_controller.dart';

class Music extends VoiceModule {
  @override
  String get name => "Music";

  @override
  List<VoiceCommand> get commands {
    return [
      PlayCommand(),
      PauseCommand(),
      NextCommand(),
      PreviousCommand(),
      WhatIsPlayingCommand(),
    ];
  }
}

class PlayCommand extends VoiceCommand {
  @override
  String get command => "Play music";

  @override
  List<String> get triggerPhrases => ["play music"];

  @override
  Future<void> execute(String inputText) async {
    await FlutterMediaController.togglePlayPause();

    final bt = BluetoothManager();
    await bt.sendText("Music playing.");

    await super.endCommand();
  }
}

class PauseCommand extends VoiceCommand {
  @override
  String get command => "Pause music";

  @override
  List<String> get triggerPhrases => ["pause music"];

  @override
  Future<void> execute(String inputText) async {
    await FlutterMediaController.togglePlayPause();

    final bt = BluetoothManager();
    await bt.sendText("Music paused.");

    await super.endCommand();
  }
}

class NextCommand extends VoiceCommand {
  @override
  String get command => "Next track";

  @override
  List<String> get triggerPhrases => ["next track", "next song", "skip"];

  @override
  Future<void> execute(String inputText) async {
    await FlutterMediaController.nextTrack();

    final bt = BluetoothManager();
    await bt.sendText("Next track triggered.");

    await super.endCommand();
  }
}

class PreviousCommand extends VoiceCommand {
  @override
  String get command => "Previous track";

  @override
  List<String> get triggerPhrases =>
      ["previous track", "previous song", "go back"];

  @override
  Future<void> execute(String inputText) async {
    await FlutterMediaController.previousTrack();

    final bt = BluetoothManager();
    await bt.sendText("Previous track triggered.");

    await super.endCommand();
  }
}

class WhatIsPlayingCommand extends VoiceCommand {
  @override
  String get command => "What is playing";

  @override
  List<String> get triggerPhrases =>
      ["what is playing", "what's playing", "what song is this"];

  @override
  Future<void> execute(String inputText) async {
    final mediaInfo = await FlutterMediaController.getCurrentMediaInfo();

    final bt = BluetoothManager();
    if (mediaInfo.isPlaying) {
      String info = "Currently playing: ${mediaInfo.track}";
      if (mediaInfo.artist.isNotEmpty) {
        info += " by ${mediaInfo.artist}";
      }

      await bt.sendText(info);
    } else {
      await bt.sendText("No music is currently playing.");
    }

    await super.endCommand();
  }
}
