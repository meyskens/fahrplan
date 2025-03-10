import 'package:chaleno/chaleno.dart';
import 'package:flutter/foundation.dart';

class TreinPositiesStop {
  String station;
  String arrival;
  String departure;
  String arrivalDelay;
  String departureDelay;
  String stationCode;

  TreinPositiesStop(
      {required this.station,
      required this.arrival,
      required this.departure,
      required this.arrivalDelay,
      required this.departureDelay,
      required this.stationCode});
}

class Treinposities {
  static Future<List<TreinPositiesStop>?> getRealtime(
      DateTime date, String number) async {
    // filter all non numeric characters from the number
    number = number.replaceAll(RegExp(r'\D'), '');
    // format date as YYYYMMDD
    var formattedDate = date.toString().substring(0, 10).replaceAll('-', '');
    debugPrint('https://treinposities.nl/ritinfo/$formattedDate/$number');
    var parser = await Chaleno()
        .load('https://treinposities.nl/ritinfo/$formattedDate/$number');

    if (parser == null) {
      debugPrint('Error loading page');
      return null;
    }

    // get all <div class="row bg-light border-bottom" style="padding-top: 6px; padding-bottom: 6px; border-top: 1px solid #dddddd;  border-bottom: 1px solid #dddddd; margin-top: -1px;font-size: 1em; font-weight: normal;" >
    var rows = parser.querySelectorAll(
        'div.row.bg-light.border-bottom[style="padding-top: 6px; padding-bottom: 6px; border-top: 1px solid #dddddd;  border-bottom: 1px solid #dddddd; margin-top: -1px;font-size: 1em; font-weight: normal;"]');

    final List<TreinPositiesStop> stops = [];

    for (var station in rows) {
      // grab station from the next nobr tag
      var stationName = station.querySelector('nobr')?.text ?? '';
      if (stationName.isEmpty || stationName.startsWith('Station')) {
        continue;
      }

      // get .col-3 .row
      var timeRes = station.querySelector('.col-3>.row');
      if (timeRes == null) {
        continue;
      }

      // the next two col-lg-6 are the times
      var times = timeRes.querySelectorAll('.col-lg-6');
      if (times == null || times.length < 2) {
        continue;
      }

      // get the times
      var arrival = times[0].text?.trim() ?? '';
      var departure = times[1].text?.trim() ?? '';

      // parse if there is " +x" for the delay
      var arrivalDelay = "";
      if (arrival.split('+').length > 1) {
        arrivalDelay = arrival.split('+')[1].trim();
        arrival = arrival.split('+')[0].trim();

        if (arrivalDelay.split(' ').length > 1) {
          arrivalDelay = arrivalDelay.split(' ')[0];
        }
      }

      var departureDelay = "";
      if (departure.split("+").length > 1) {
        departureDelay = departure.split("+")[1].trim();
        departure = departure.split("+")[0].trim();

        if (departureDelay.split(' ').length > 1) {
          departureDelay = departureDelay.split(' ')[0];
        }
      }

      // get station code from <href="/rit_per_station/$CODE/$NUMBER"
      var stationCode = station
              .querySelector('a[href^="/rit_per_station"]')
              ?.attr("href")
              ?.split('/')[2] ??
          '';

      stops.add(TreinPositiesStop(
          station: stationName,
          arrival: arrival,
          departure: departure,
          arrivalDelay: arrivalDelay,
          departureDelay: departureDelay,
          stationCode: stationCode));
    }

    return stops;
  }
}
