class VoiceCommandHelper {
  List<VoiceCommand> commands;

  VoiceCommandHelper({required this.commands});

  void parseCommand(String transcription) {
    transcription = _prepareTranscript(transcription);

    for (var cmd in commands) {
      for (var trigger in cmd.phrases) {
        if (transcription.startsWith(trigger.toLowerCase())) {
          cmd.fn(_removeTrigger(transcription, trigger));
          return;
        }
      }
    }

    throw Exception('no command found for "$transcription"');
  }

  String _prepareTranscript(String transcription) {
    // remove all [.*] tags
    transcription = transcription.replaceAll(RegExp(r'\[.*?\]'), '');
    // remove all double spaces
    transcription = transcription.replaceAll(RegExp(r' {2,}'), ' ');
    return transcription.toLowerCase().replaceAll(".", "").trim();
  }

  String _removeTrigger(String transcription, String trigger) {
    return transcription
        .toLowerCase()
        .replaceFirst(trigger, "")
        .replaceAll(".", "")
        .trim();
  }
}

class VoiceCommand {
  final String command;
  final List<String> phrases;
  final Function(String) fn;

  VoiceCommand(
      {required this.command, required this.phrases, required this.fn});
}
