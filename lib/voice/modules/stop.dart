import 'package:fahrplan/models/fahrplan/stop.dart';
import 'package:fahrplan/services/bluetooth_manager.dart';
import 'package:fahrplan/services/stops_manager.dart';
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

class Stop extends VoiceModule {
  @override
  String get name => "Stop";

  @override
  List<VoiceCommand> get commands {
    return [
      DeleteStop(),
      DeleteCurrentStop(),
    ];
  }
}

class DeleteStop extends VoiceCommand {
  @override
  String get command => "Delete stop";

  @override
  List<String> get triggerPhrases => [
        "delete stop",
        "remove stop",
        "cancel stop",
      ];

  @override
  Future<void> execute(String inputText) async {
    final allStops = await FahrplanStopItem.getAllStopTitles();
    final bestMatch = await Voicecontrol.findBestMatch(
        inputText, allStops.map((e) => "delete stop $e").toList());

    String stopTitle = "";
    if (bestMatch > -1) {
      stopTitle = allStops[bestMatch];
    } else {
      stopTitle = _removeTriggers(inputText, triggerPhrases);
    }

    final bt = BluetoothManager();
    final success = await FahrplanStopItem.deleteStopByTitle(stopTitle);

    if (success) {
      bt.sendText('Stop "$stopTitle" deleted');
      StopsManager().reload();
      bt.sync();
    } else {
      bt.sendText('No stop found for "$stopTitle"');
    }

    await super.endCommand();
  }
}

class DeleteCurrentStop extends VoiceCommand {
  @override
  String get command => "Delete current stop";

  @override
  List<String> get triggerPhrases => [
        "delete current stop",
        "remove current stop",
        "cancel current stop",
        "delete this stop",
        "remove this stop",
        "cancel this stop",
      ];

  @override
  Future<void> execute(String inputText) async {
    final bt = BluetoothManager();
    final stopsManager = StopsManager();
    final currentStop = stopsManager.currentlyTriggeringStop;

    if (currentStop == null) {
      bt.sendText('No stop is currently triggering');
      await super.endCommand();
      return;
    }

    final success = await FahrplanStopItem.deleteStopByUuid(currentStop.uuid);

    if (success) {
      bt.sendText('Current stop "${currentStop.title}" deleted');
      stopsManager.currentlyTriggeringStop = null;
      stopsManager.reload();
      bt.sync();
    } else {
      bt.sendText('Failed to delete current stop');
    }

    await super.endCommand();
  }
}
