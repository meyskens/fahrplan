import 'package:fahrplan/models/fahrplan/checklist.dart';
import 'package:fahrplan/services/bluetooth_manager.dart';
import 'package:fahrplan/voice/module.dart';
import 'package:fahrplan/voice/voicecontrol.dart';

String _removeTriggers(String transcription, List<String> triggers) {
  for (var trigger in triggers) {
    transcription = transcription
        .toLowerCase()
        .replaceFirst(trigger, "")
        .replaceAll(".", "")
        .trim();
  }
  return transcription;
}

class Checklist extends VoiceModule {
  @override
  String get name => "Checklist";

  @override
  List<VoiceCommand> get commands {
    return [
      OpenChecklist(),
      CloseChecklist(),
    ];
  }
}

class OpenChecklist extends VoiceCommand {
  @override
  String get command => "Open checklist";

  @override
  List<String> get triggerPhrases => [
        "open checklist",
        "open check list",
        "show checklist",
        "show check list",
      ];

  @override
  Future<void> execute(String inputText) async {
    final allLists = FahrplanChecklist.getAllChecklistNames();
    final bestMatch = await Voicecontrol.findBestMatch(
        inputText, allLists.map((e) => "open checklist $e").toList());

    String listName = "";
    if (bestMatch > -1) {
      listName = allLists[bestMatch];
    } else {
      listName = _removeTriggers(inputText, triggerPhrases);
    }
    final list = FahrplanChecklist.displayChecklistFor(listName);

    final bt = BluetoothManager();
    if (list != null) {
      bt.sync();
    } else {
      bt.sendText('No checklist found for "$listName"');
    }

    await super.endCommand();
  }
}

class CloseChecklist extends VoiceCommand {
  @override
  String get command => "Close checklist";

  @override
  List<String> get triggerPhrases => [
        "close checklist",
        "close check list",
        "closed checklist",
        "closed check list"
      ];

  @override
  Future<void> execute(String inputText) async {
    final allLists = FahrplanChecklist.getAllChecklistNames();
    final bestMatch = await Voicecontrol.findBestMatch(
        inputText, allLists.map((e) => "close checklist $e").toList());

    String listName = "";
    if (bestMatch > -1) {
      listName = allLists[bestMatch];
    } else {
      listName = _removeTriggers(inputText, triggerPhrases);
    }
    final list = FahrplanChecklist.hideChecklistFor(listName);

    final bt = BluetoothManager();
    if (list != null) {
      bt.sync();
    } else {
      bt.sendText('No checklist found for "$listName"');
    }

    await super.endCommand();
  }
}
