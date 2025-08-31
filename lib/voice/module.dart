import 'package:fahrplan/services/bluetooth_manager.dart';

/// Abstract base class for voice modules that group related voice commands
abstract class VoiceModule {
  /// The display name of this voice module
  String get name;

  /// List of voice commands supported by this module
  List<VoiceCommand> get commands;
}

/// Abstract base class for individual voice commands
abstract class VoiceCommand {
  /// A human-readable description of what this command does
  String get command;

  /// List of trigger phrases that can activate this command
  /// The voice control system will try to match user speech against these phrases
  List<String> get triggerPhrases;

  /// Execute the command with the given input text
  /// The inputText parameter contains any additional parameters spoken after the trigger phrase
  Future<void> execute(String inputText);

  Future<void> endCommand() async {
    // sleep 5 seconds and then clear the screen
    await Future.delayed(const Duration(seconds: 5));
    final bt = BluetoothManager();
    await bt.clearScreen();
  }
}
