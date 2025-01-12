import 'dart:convert';
import 'package:fahrplan/models/fahrplan/widgets/fahrplan_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:fahrplan/models/g1/note.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _allowedProducts = [
  'nationalExpress',
  'national',
  'regionalExp',
  'regional',
  'suburban'
];

class TraewellingWidget implements FahrplanWidget {
  String? username;
  String? token;
  String? apiURL;

  @override
  int getPriority() {
    return 1;
  }

  Future<void> loadCredentials() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    username = prefs.getString('traewelling_username');
    token = prefs.getString('traewelling_token');
    apiURL = prefs.getString('traewelling_apiURL') ??
        'https://traewelling.de/api/v1';
  }

  Future<void> saveCredentials(
      String username, String token, String apiURL) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('traewelling_username', username);
    await prefs.setString('traewelling_token', token);
    await prefs.setString('traewelling_apiURL', apiURL);

    await loadCredentials();
  }

  Future<_TraewellingResponse> _getTrips() async {
    final response = await http.get(
      Uri.parse('$apiURL/user/$username/statuses'),
      headers: <String, String>{
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return _TraewellingResponse.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load trips');
    }
  }

  Future<_TraewellingStationResponse> _getStationTable(String id) async {
    final response = await http.get(
      Uri.parse('$apiURL/station/$id/departures'),
      headers: <String, String>{
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return _TraewellingStationResponse.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load trips');
    }
  }

  Future<List<Note>> _generateDeparture(
      String stationId, Train? currentTrain) async {
    final response = await _getStationTable(stationId);
    if (response.data == null || response.data!.isEmpty) {
      return [];
    }

    // filter all non "nationalExpress" "national" "regionalExp" "regional" "suburban"
    final filteredData = response.data!
        .where((element) =>
            _allowedProducts.contains(element.line?.product ?? '') &&
            (currentTrain != null
                ? (element.line?.name ?? '') != currentTrain.lineName
                : true))
        .toList();

    // filter out all trains that have already left
    filteredData.removeWhere((element) {
      DateTime plannedWhen = DateTime.parse(element.plannedWhen ?? '');
      plannedWhen = plannedWhen.add(Duration(minutes: element.delay ?? 0));
      return plannedWhen.isBefore(DateTime.now());
    });

    // mandatory reservation sucks!
    filteredData.removeWhere((element) =>
        element.line == null ||
        element.line?.name == null ||
        element.line!.name!.startsWith("EUR") ||
        element.line!.name!.startsWith("EST"));

    // remove trains that leave before our current train arrives
    if (currentTrain != null) {
      filteredData.removeWhere((element) {
        DateTime plannedWhen = DateTime.parse(element.plannedWhen ?? '');
        plannedWhen = plannedWhen.add(Duration(minutes: element.delay ?? 0));
        plannedWhen = plannedWhen.add(Duration(
            minutes:
                2)); // add 2 minutes change time, would be 5 but Switzerland is a thing!
        DateTime arrival = DateTime.parse(
            currentTrain.destination?.arrivalReal ??
                currentTrain.destination?.arrivalPlanned ??
                '');
        return plannedWhen.isBefore(arrival);
      });
    }

    if (filteredData.isEmpty) {
      debugPrint('No trains found after filtering');
      return [];
    }

    // select first 4
    if (filteredData.length > 4) {
      filteredData.removeRange(4, filteredData.length);
    }

    String text = '';
    for (final item in filteredData) {
      DateTime plannedWhen = DateTime.parse(item.plannedWhen ?? '').toLocal();
      double delayMin = (item.delay ?? 0) / 60;
      String delay = delayMin > 5 ? ' (+${delayMin.round()})' : '';
      String platform = item.plannedPlatform ?? item.platform ?? '';
      if (platform.isNotEmpty) {
        platform = 'pl. $platform';
      }
      String line = item.line?.name ?? '';
      String destination = item.destination?.name ?? '';
      // shorten destination name
      if (destination.length > 10) {
        destination = '${destination.substring(0, 10).trim()}...';
      }

      text +=
          '${NoteSupportedIcons.CHECKBOX} ${DateFormat('HH:mm').format(plannedWhen)}$delay [$line] to $destination $platform\n';
    }
    return [
      Note(
          noteNumber: 1, // dummy
          name: filteredData.first.stop?.name ?? 'Departures',
          text: text)
    ];
  }

  @override
  Future<List<Note>> generateDashboardItems() async {
    final notes = <Note>[];

    await loadCredentials();
    if (username == null || username!.isEmpty) {
      return [];
    }

    final response = await _getTrips();
    if (response.data!.isEmpty) {
      return [];
    }

    List<Train> currentTrains = [];
    // check if there is a train with a arrival in the future
    for (final trip in response.data!) {
      if (trip.train != null && trip.train!.destination != null) {
        final arrival = DateTime.parse(trip.train!.destination!.arrivalReal ??
            trip.train!.destination!.arrivalPlanned!);
        if (arrival.isAfter(DateTime.now())) {
          currentTrains.add(trip.train!);
        }
      }
    }

    if (currentTrains.isEmpty) {
      final String arrival =
          response.data!.first.train!.destination!.arrivalReal ??
              response.data!.first.train!.destination!.arrivalPlanned ??
              '';
      if (arrival.isEmpty) {
        return [];
      }
      if (DateTime.parse(arrival)
          .add(Duration(minutes: 10))
          .isAfter(DateTime.now())) {
        final stationId = response.data?.first.train?.destination?.id;
        if (stationId != null) {
          return await _generateDeparture(
              stationId.toString(), response.data?.first.train);
        }
      }
      return [];
    }

    // sort by departure time
    currentTrains.sort((a, b) {
      final aDeparture = DateTime.parse(
          a.origin!.departureReal ?? a.origin!.departurePlanned!);
      final bDeparture = DateTime.parse(
          b.origin!.departureReal ?? b.origin!.departurePlanned!);
      return aDeparture.compareTo(bDeparture);
    });

    final train = currentTrains.first;

    DateTime departurePlanned =
        DateTime.parse(train.origin?.departurePlanned ?? '');
    DateTime? departureReal = train.origin?.departureReal == null
        ? null
        : DateTime.parse(train.origin!.departureReal!);
    DateTime arrivalPlanned =
        DateTime.parse(train.destination?.arrivalPlanned ?? '');
    DateTime? arrivalReal = train.destination?.arrivalReal == null
        ? null
        : DateTime.parse(train.destination!.arrivalReal!);

    String departureTime =
        DateFormat('HH:mm').format(departurePlanned.toLocal());
    // if departureReal is at least 1 minute after planned note the delay with (+X)
    if (departureReal != null &&
        departureReal.difference(departurePlanned).inMinutes >= 1) {
      departureTime +=
          ' (+${departureReal.difference(departurePlanned).inMinutes} ${DateFormat('HH:mm').format(departureReal.toLocal())})';
    }

    String arrivalTime = DateFormat('HH:mm').format(arrivalPlanned.toLocal());
    // if arrivalReal is at least 1 minute after planned note the delay with (+X)
    if (arrivalReal != null &&
        arrivalReal.difference(arrivalPlanned).inMinutes >= 1) {
      arrivalTime +=
          ' (+${arrivalReal.difference(arrivalPlanned).inMinutes} ${DateFormat('HH:mm').format(arrivalReal.toLocal())})';
    }

    // convert minutes to hours and minutes, drop hours if 0
    String duration = '';
    if (train.duration! > 59) {
      duration += '${train.duration! ~/ 60}h ';
    } else if (train.duration! == 60) {
      duration += '1h';
    }
    duration += '${train.duration! % 60}min';
    double distance = train.distance! / 1000;

    String remainingDuration = '';
    int remainingMinutes = arrivalPlanned.difference(DateTime.now()).inMinutes;
    if (remainingMinutes > 59) {
      remainingDuration += '${remainingMinutes ~/ 60}h ';
    } else if (remainingMinutes == 60) {
      remainingDuration += '1h';
    }
    remainingDuration += '${remainingMinutes % 60}m';

    if (remainingMinutes < 5) {
      notes.addAll(
          await _generateDeparture(train.destination!.id.toString(), train));
    }

    notes.add(Note(
      noteNumber: 1, // dummy
      name: '[${train.lineName}] to ${train.destination?.name}',
      text:
          '[$departureTime] ${train.origin?.name} pl. ${train.origin?.departurePlatformReal ?? train.origin?.departurePlatformPlanned ?? ''}\n'
          'Operator: ${train.operator?.name ?? 'Unknown'}\n'
          'dist: ${distance.round()}km  pts: ${train.points ?? 0}  dur: $duration\n'
          '-> [$arrivalTime] ($remainingDuration) ${train.destination?.name} pl. ${train.destination?.arrivalPlatformReal ?? train.destination?.arrivalPlatformPlanned ?? ''}',
    ));

    return notes;
  }
}

class _TraewellingResponse {
  List<Data>? data;
  _TraewellingResponse();

  _TraewellingResponse.fromJson(Map<String, dynamic> json) {
    if (json['data'] != null) {
      data = <Data>[];
      json['data'].forEach((v) {
        data!.add(Data.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (this.data != null) {
      data['data'] = this.data!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Data {
  int? id;
  String? body;
  int? user;
  String? username;
  String? profilePicture;
  bool? liked;
  bool? isLikable;
  String? createdAt;
  Train? train;
  UserDetails? userDetails;

  Data({
    this.id,
    this.body,
    this.user,
    this.username,
    this.profilePicture,
    this.liked,
    this.isLikable,
    this.createdAt,
    this.train,
    this.userDetails,
  });

  Data.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    body = json['body'];
    user = json['user'];
    username = json['username'];
    profilePicture = json['profilePicture'];
    liked = json['liked'];
    isLikable = json['isLikable'];
    createdAt = json['createdAt'];
    train = json['train'] != null ? Train.fromJson(json['train']) : null;
    userDetails = json['userDetails'] != null
        ? UserDetails.fromJson(json['userDetails'])
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['body'] = body;
    data['user'] = user;
    data['username'] = username;
    data['profilePicture'] = profilePicture;
    data['liked'] = liked;
    data['isLikable'] = isLikable;
    data['createdAt'] = createdAt;
    if (train != null) {
      data['train'] = train!.toJson();
    }
    if (userDetails != null) {
      data['userDetails'] = userDetails!.toJson();
    }
    return data;
  }
}

class Train {
  int? trip;
  String? hafasId;
  String? category;
  String? number;
  String? lineName;
  int? journeyNumber;
  int? distance;
  int? points;
  int? duration;
  Origin? origin;
  Origin? destination;
  Operator? operator;

  Train(
      {this.trip,
      this.hafasId,
      this.category,
      this.number,
      this.lineName,
      this.journeyNumber,
      this.distance,
      this.points,
      this.duration,
      this.origin,
      this.destination,
      this.operator});

  Train.fromJson(Map<String, dynamic> json) {
    trip = json['trip'];
    hafasId = json['hafasId'];
    category = json['category'];
    number = json['number'];
    lineName = json['lineName'];
    journeyNumber = json['journeyNumber'];
    distance = json['distance'];
    points = json['points'];
    duration = json['duration'];
    origin = json['origin'] != null ? Origin.fromJson(json['origin']) : null;
    destination = json['destination'] != null
        ? Origin.fromJson(json['destination'])
        : null;
    operator =
        json['operator'] != null ? Operator.fromJson(json['operator']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['trip'] = trip;
    data['hafasId'] = hafasId;
    data['category'] = category;
    data['number'] = number;
    data['lineName'] = lineName;
    data['journeyNumber'] = journeyNumber;
    data['distance'] = distance;
    data['points'] = points;
    data['duration'] = duration;
    if (origin != null) {
      data['origin'] = origin!.toJson();
    }
    if (destination != null) {
      data['destination'] = destination!.toJson();
    }
    if (operator != null) {
      data['operator'] = operator!.toJson();
    }
    return data;
  }
}

class Origin {
  int? id;
  String? name;
  String? rilIdentifier;
  int? evaIdentifier;
  String? arrival;
  String? arrivalPlanned;
  String? arrivalReal;
  String? arrivalPlatformPlanned;
  String? arrivalPlatformReal;
  String? departure;
  String? departurePlanned;
  String? departureReal;
  String? departurePlatformPlanned;
  String? departurePlatformReal;
  String? platform;
  bool? isArrivalDelayed;
  bool? isDepartureDelayed;
  bool? cancelled;

  Origin(
      {this.id,
      this.name,
      this.rilIdentifier,
      this.evaIdentifier,
      this.arrival,
      this.arrivalPlanned,
      this.arrivalReal,
      this.arrivalPlatformPlanned,
      this.arrivalPlatformReal,
      this.departure,
      this.departurePlanned,
      this.departureReal,
      this.departurePlatformPlanned,
      this.departurePlatformReal,
      this.platform,
      this.isArrivalDelayed,
      this.isDepartureDelayed,
      this.cancelled});

  Origin.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    rilIdentifier = json['rilIdentifier'];
    evaIdentifier = json['evaIdentifier'];
    arrival = json['arrival'];
    arrivalPlanned = json['arrivalPlanned'];
    arrivalReal = json['arrivalReal'];
    arrivalPlatformPlanned = json['arrivalPlatformPlanned'];
    arrivalPlatformReal = json['arrivalPlatformReal'];
    departure = json['departure'];
    departurePlanned = json['departurePlanned'];
    departureReal = json['departureReal'];
    departurePlatformPlanned = json['departurePlatformPlanned'];
    departurePlatformReal = json['departurePlatformReal'];
    platform = json['platform'];
    isArrivalDelayed = json['isArrivalDelayed'];
    isDepartureDelayed = json['isDepartureDelayed'];
    cancelled = json['cancelled'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['name'] = name;
    data['rilIdentifier'] = rilIdentifier;
    data['evaIdentifier'] = evaIdentifier;
    data['arrival'] = arrival;
    data['arrivalPlanned'] = arrivalPlanned;
    data['arrivalReal'] = arrivalReal;
    data['arrivalPlatformPlanned'] = arrivalPlatformPlanned;
    data['arrivalPlatformReal'] = arrivalPlatformReal;
    data['departure'] = departure;
    data['departurePlanned'] = departurePlanned;
    data['departureReal'] = departureReal;
    data['departurePlatformPlanned'] = departurePlatformPlanned;
    data['departurePlatformReal'] = departurePlatformReal;
    data['platform'] = platform;
    data['isArrivalDelayed'] = isArrivalDelayed;
    data['isDepartureDelayed'] = isDepartureDelayed;
    data['cancelled'] = cancelled;
    return data;
  }
}

class Operator {
  String? identifier;
  String? name;

  Operator({this.identifier, this.name});

  Operator.fromJson(Map<String, dynamic> json) {
    identifier = json['identifier'];
    name = json['name'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['identifier'] = identifier;
    data['name'] = name;
    return data;
  }
}

class UserDetails {
  int? id;
  String? displayName;
  String? username;
  String? profilePicture;
  String? mastodonUrl;
  bool? preventIndex;

  UserDetails(
      {this.id,
      this.displayName,
      this.username,
      this.profilePicture,
      this.mastodonUrl,
      this.preventIndex});

  UserDetails.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    displayName = json['displayName'];
    username = json['username'];
    profilePicture = json['profilePicture'];
    mastodonUrl = json['mastodonUrl'];
    preventIndex = json['preventIndex'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['displayName'] = displayName;
    data['username'] = username;
    data['profilePicture'] = profilePicture;
    data['mastodonUrl'] = mastodonUrl;
    data['preventIndex'] = preventIndex;
    return data;
  }
}

class _TraewellingStationResponse {
  List<TraewellingStationResponseData>? data;

  _TraewellingStationResponse();

  _TraewellingStationResponse.fromJson(Map<String, dynamic> json) {
    if (json['data'] != null) {
      data = <TraewellingStationResponseData>[];
      json['data'].forEach((v) {
        data!.add(TraewellingStationResponseData.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (this.data != null) {
      data['data'] = this.data!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class TraewellingStationResponseData {
  String? tripId;
  Stop? stop;
  String? when;
  String? plannedWhen;
  int? delay;
  String? platform;
  String? plannedPlatform;
  String? prognosisType;
  Line? line;
  Stop? destination;
  Station? station;

  TraewellingStationResponseData(
      {this.tripId,
      this.stop,
      this.when,
      this.plannedWhen,
      this.delay,
      this.platform,
      this.plannedPlatform,
      this.prognosisType,
      this.line,
      this.destination,
      this.station});

  TraewellingStationResponseData.fromJson(Map<String, dynamic> json) {
    tripId = json['tripId'];
    stop = json['stop'] != null ? Stop.fromJson(json['stop']) : null;
    when = json['when'];
    plannedWhen = json['plannedWhen'];
    delay = json['delay'];
    platform = json['platform'];
    plannedPlatform = json['plannedPlatform'];
    prognosisType = json['prognosisType'];
    line = json['line'] != null ? Line.fromJson(json['line']) : null;
    destination =
        json['destination'] != null ? Stop.fromJson(json['destination']) : null;
    station =
        json['station'] != null ? Station.fromJson(json['station']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['tripId'] = tripId;
    if (stop != null) {
      data['stop'] = stop!.toJson();
    }
    data['when'] = when;
    data['plannedWhen'] = plannedWhen;
    data['delay'] = delay;
    data['platform'] = platform;
    data['plannedPlatform'] = plannedPlatform;
    data['prognosisType'] = prognosisType;
    if (line != null) {
      data['line'] = line!.toJson();
    }
    if (destination != null) {
      data['destination'] = destination!.toJson();
    }
    if (station != null) {
      data['station'] = station!.toJson();
    }
    return data;
  }
}

class Stop {
  String? type;
  String? id;
  String? name;
  Location? location;
  Products? products;

  Stop({this.type, this.id, this.name, this.location, this.products});

  Stop.fromJson(Map<String, dynamic> json) {
    type = json['type'];
    id = json['id'];
    name = json['name'];
    location =
        json['location'] != null ? Location.fromJson(json['location']) : null;
    products =
        json['products'] != null ? Products.fromJson(json['products']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['type'] = type;
    data['id'] = id;
    data['name'] = name;
    if (location != null) {
      data['location'] = location!.toJson();
    }
    if (products != null) {
      data['products'] = products!.toJson();
    }
    return data;
  }
}

class Location {
  String? type;
  String? id;
  double? latitude;
  double? longitude;

  Location({this.type, this.id, this.latitude, this.longitude});

  Location.fromJson(Map<String, dynamic> json) {
    type = json['type'];
    id = json['id'];
    latitude = json['latitude'];
    longitude = json['longitude'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['type'] = type;
    data['id'] = id;
    data['latitude'] = latitude;
    data['longitude'] = longitude;
    return data;
  }
}

class Products {
  bool? nationalExpress;
  bool? national;
  bool? regionalExp;
  bool? regional;
  bool? suburban;
  bool? bus;
  bool? ferry;
  bool? subway;
  bool? tram;
  bool? taxi;

  Products(
      {this.nationalExpress,
      this.national,
      this.regionalExp,
      this.regional,
      this.suburban,
      this.bus,
      this.ferry,
      this.subway,
      this.tram,
      this.taxi});

  Products.fromJson(Map<String, dynamic> json) {
    nationalExpress = json['nationalExpress'];
    national = json['national'];
    regionalExp = json['regionalExp'];
    regional = json['regional'];
    suburban = json['suburban'];
    bus = json['bus'];
    ferry = json['ferry'];
    subway = json['subway'];
    tram = json['tram'];
    taxi = json['taxi'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['nationalExpress'] = nationalExpress;
    data['national'] = national;
    data['regionalExp'] = regionalExp;
    data['regional'] = regional;
    data['suburban'] = suburban;
    data['bus'] = bus;
    data['ferry'] = ferry;
    data['subway'] = subway;
    data['tram'] = tram;
    data['taxi'] = taxi;
    return data;
  }
}

class Line {
  String? type;
  String? id;
  String? fahrtNr;
  String? name;
  bool? public;
  String? adminCode;
  String? productName;
  String? mode;
  String? product;
  Operator? operator;

  Line(
      {this.type,
      this.id,
      this.fahrtNr,
      this.name,
      this.public,
      this.adminCode,
      this.productName,
      this.mode,
      this.product,
      this.operator});

  Line.fromJson(Map<String, dynamic> json) {
    type = json['type'];
    id = json['id'];
    fahrtNr = json['fahrtNr'];
    name = json['name'];
    public = json['public'];
    adminCode = json['adminCode'];
    productName = json['productName'];
    mode = json['mode'];
    product = json['product'];
    operator =
        json['operator'] != null ? Operator.fromJson(json['operator']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['type'] = type;
    data['id'] = id;
    data['fahrtNr'] = fahrtNr;
    data['name'] = name;
    data['public'] = public;
    data['adminCode'] = adminCode;
    data['productName'] = productName;
    data['mode'] = mode;
    data['product'] = product;
    if (operator != null) {
      data['operator'] = operator!.toJson();
    }
    return data;
  }
}

class Station {
  int? id;
  String? name;
  String? localizedName;

  Station({
    this.id,
    this.name,
    this.localizedName,
  });

  Station.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    localizedName = json['localized_name'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['name'] = name;
    data['localized_name'] = localizedName;
    return data;
  }
}

class Times {
  String? now;
  String? prev;
  String? next;

  Times({this.now, this.prev, this.next});

  Times.fromJson(Map<String, dynamic> json) {
    now = json['now'];
    prev = json['prev'];
    next = json['next'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['now'] = now;
    data['prev'] = prev;
    data['next'] = next;
    return data;
  }
}
