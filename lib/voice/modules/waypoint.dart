import 'package:chrono_dart/chrono_dart.dart';
import 'package:fahrplan/models/fahrplan/waypoint.dart';
import 'package:fahrplan/services/bluetooth_manager.dart';
import 'package:fahrplan/services/llm_service.dart';
import 'package:fahrplan/voice/module.dart';
import 'package:fahrplan/voice/voicecontrol.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class Waypoint extends VoiceModule {
  @override
  String get name => "Waypoint";

  @override
  List<VoiceCommand> get commands {
    return [
      AddWaypoint(),
      DeleteWaypoint(),
      DelayWaypoint(),
    ];
  }
}

class DeleteWaypoint extends VoiceCommand {
  @override
  String get command => "Delete waypoint";

  @override
  List<String> get triggerPhrases => [
        "delete waypoint",
        "remove waypoint",
        "cancel waypoint",
      ];

  @override
  Future<void> execute(String inputText) async {
    final allWaypoints = FahrplanWaypoint.getAllWaypointDescriptions();
    final bestMatch = await Voicecontrol.findBestMatch(
        inputText, allWaypoints.map((e) => "delete waypoint $e").toList());

    String waypointDesc = "";
    if (bestMatch > -1) {
      waypointDesc = allWaypoints[bestMatch];
    } else {
      waypointDesc = _removeTriggers(inputText, triggerPhrases);
    }

    final bt = BluetoothManager();
    final success = FahrplanWaypoint.deleteWaypointByDescription(waypointDesc);

    if (success) {
      bt.sendText('Waypoint "$waypointDesc" deleted');
      bt.sync();
    } else {
      bt.sendText('No waypoint found for "$waypointDesc"');
    }

    await super.endCommand();
  }
}

class DelayWaypoint extends VoiceCommand {
  @override
  String get command => "Postpone waypoint";

  @override
  List<String> get triggerPhrases => [
        "delay waypoint",
        "delay waypoint to tomorrow",
        "postpone waypoint",
        "postpone waypoint to tomorrow",
        "move waypoint to tomorrow",
      ];

  @override
  Future<void> execute(String inputText) async {
    final allWaypoints = FahrplanWaypoint.getAllWaypointDescriptions();
    final bestMatch = await Voicecontrol.findBestMatch(
        inputText, allWaypoints.map((e) => "delay waypoint $e").toList());

    String waypointDesc = "";
    if (bestMatch > -1) {
      waypointDesc = allWaypoints[bestMatch];
    } else {
      waypointDesc = _removeTriggers(inputText, triggerPhrases);
    }

    final bt = BluetoothManager();
    final success = FahrplanWaypoint.delayWaypointByDescription(waypointDesc);

    if (success) {
      bt.sendText('Waypoint "$waypointDesc" delayed to tomorrow');
      bt.sync();
    } else {
      bt.sendText('No waypoint found for "$waypointDesc"');
    }

    await super.endCommand();
  }
}

class AddWaypoint extends VoiceCommand {
  @override
  String get command => "Add waypoint";

  @override
  List<String> get triggerPhrases => [
        "add waypoint",
        "create waypoint",
        "new waypoint",
        "set waypoint",
      ];

  @override
  Future<void> execute(String inputText) async {
    final bt = BluetoothManager();

    // Remove trigger phrases to get the remaining text
    String remainingText = _removeTriggers(inputText, triggerPhrases);

    // Parse the time using chrono_dart
    final parsedResults = Chrono.parse(remainingText);

    if (parsedResults.isEmpty) {
      bt.sendText('Could not understand the time. Please try again.');
      await super.endCommand();
      return;
    }

    final parsedResult = parsedResults.first;
    DateTime parsedTime = parsedResult.start.date();

    // Extract description by removing the parsed date/time text from the input
    String description = remainingText;
    if (parsedResult.text.isNotEmpty) {
      description = remainingText.replaceAll(parsedResult.text, '').trim();
    }

    // If description is empty, use a default
    if (description.isEmpty) {
      description = 'Waypoint';
    }

    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString('voice_command_mode') ?? 'fuzzy';

    if (mode == 'llm') {
      // Use LLM to generate a concise description
      final summary = await LLMService.summaryGen(inputText);
      if (summary != null && summary.isNotEmpty) {
        description = summary;
      }
    }

    // Create and save the waypoint
    try {
      final waypoint = FahrplanWaypoint(
        description: description,
        startTime: parsedTime,
      );

      final box = Hive.box<FahrplanWaypoint>('fahrplanWaypointBox');
      await box.add(waypoint);

      final timeStr =
          '${parsedTime.day}/${parsedTime.month} ${parsedTime.hour.toString().padLeft(2, '0')}:${parsedTime.minute.toString().padLeft(2, '0')}';
      bt.sendText('Waypoint "$description" added for $timeStr');
      bt.sync();
    } catch (e) {
      debugPrint('Error adding waypoint: $e');
      bt.sendText('Error adding waypoint. Please try again.');
    }

    await super.endCommand();
  }
}
