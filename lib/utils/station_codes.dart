import 'package:fast_csv/fast_csv.dart' as fast_csv;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fuzzywuzzy/fuzzywuzzy.dart';

class NSStations {
  static final NSStations singleton = NSStations._internal();

  factory NSStations() {
    return singleton;
  }

  final Map<String, String> _stationCodes = {};

  NSStations._internal();

  Future<void> load() async {
    final csvString =
        await rootBundle.loadString('assets/train-data/nl-stations.csv');
    final csvTable = fast_csv.parse(csvString);

    debugPrint('Loaded ${csvTable.length} stations');

    for (final row in csvTable) {
      _stationCodes[row[2]] = row[1];
    }
  }

  String? getStationCodeForUIC(String uicCode) {
    return _stationCodes[uicCode];
  }
}

class SNCBStations {
  static final SNCBStations singleton = SNCBStations._internal();

  factory SNCBStations() {
    return singleton;
  }

  final Map<String, String> _stationCodes = {};

  Future<void> load() async {
    if (_stationCodes.isNotEmpty) {
      return;
    }
    final csvString =
        await rootBundle.loadString('assets/train-data/be-stations.csv');
    final csvTable = fast_csv.parse(csvString);

    for (final row in csvTable) {
      // URI,name,alternative-fr,alternative-nl,alternative-de,alternative-en,taf-tap-code,telegraph-code,country-code,longitude,latitude,avg_stop_times,official_transfer_time

      final name = row[1];
      final alternariveFr = row[2];
      final alternativeNl = row[3];
      final alternativeDe = row[4];
      final alternativeEn = row[5];
      final telegraphCode = row[7];

      // Long live Belgium!
      if (name.isNotEmpty) {
        _stationCodes[name] = telegraphCode;
      }
      if (alternariveFr.isNotEmpty) {
        _stationCodes[alternariveFr] = telegraphCode;
      }
      if (alternativeNl.isNotEmpty) {
        _stationCodes[alternativeNl] = telegraphCode;
      }
      if (alternativeDe.isNotEmpty) {
        _stationCodes[alternativeDe] = telegraphCode;
      }
      if (alternativeEn.isNotEmpty) {
        _stationCodes[alternativeEn] = telegraphCode;
      }
    }
  }

  SNCBStations._internal();

  String? getStationCodeForName(String name) {
    // fuzzy search
    final res = extractOne(query: name, choices: _stationCodes.keys.toList());
    return _stationCodes[res.choice];
  }
}
