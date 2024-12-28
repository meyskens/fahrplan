import 'dart:convert';
import 'package:fahrplan/models/fahrplan/widgets/fahrplan_widget.dart';
import 'package:http/http.dart' as http;

import 'package:fahrplan/models/g1/note.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TraewellingWidget implements FahrplanWidget {
  String? username;
  String? token;

  @override
  int getPriority() {
    return 1;
  }

  Future<void> loadCredentials() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    username = prefs.getString('traewelling_username');
    token = prefs.getString('traewelling_token');
  }

  Future<void> saveCredentials(String username, String token) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('traewelling_username', username);
    await prefs.setString('traewelling_token', token);

    await loadCredentials();
  }

  Future<_TraewellingResponse> _getTrips() async {
    final response = await http.get(
      Uri.parse('https://traewelling.de/api/v1/user/$username/statuses'),
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

  @override
  Future<List<Note>> generateDashboardItems() async {
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
    DateTime departureReal = DateTime.parse(train.origin?.departureReal ?? '');
    DateTime arrivalPlanned =
        DateTime.parse(train.destination?.arrivalPlanned ?? '');
    DateTime arrivalReal = DateTime.parse(train.destination?.arrivalReal ?? '');

    String departureTime = DateFormat('HH:mm').format(departurePlanned);
    // if departureReal is at least 1 minute after planned note the delay with (+X)
    if (departureReal.difference(departurePlanned).inMinutes >= 1) {
      departureTime +=
          ' (+${departureReal.difference(departurePlanned).inMinutes} ${DateFormat('HH:mm').format(departureReal)})';
    }

    String arrivalTime = DateFormat('HH:mm').format(arrivalPlanned);
    // if arrivalReal is at least 1 minute after planned note the delay with (+X)
    if (arrivalReal.difference(arrivalPlanned).inMinutes >= 1) {
      arrivalTime +=
          ' (+${arrivalReal.difference(arrivalPlanned).inMinutes} ${DateFormat('HH:mm').format(arrivalReal)})';
    }

    // convert minutes to hours and minutes, drop hours if 0
    String duration = '';
    if (train.duration! > 60) {
      duration += '${train.duration! ~/ 60}h ';
    }
    duration += '${train.duration! % 60}min';
    double distance = train.distance! / 1000;

    String remainingDuration = '';
    int remainingMinutes = arrivalPlanned.difference(DateTime.now()).inMinutes;
    if (remainingMinutes > 60) {
      remainingDuration += '${remainingMinutes ~/ 60}h ';
    }
    remainingDuration += '${remainingMinutes % 60}min';

    return [
      Note(
        noteNumber: 1, // dummy
        name: '[${train.lineName}] to ${train.destination?.name}',
        text:
            '[$departureTime] ${train.origin?.name} pl. ${train.origin?.arrivalPlatformReal ?? train.origin?.arrivalPlanned ?? ''}\n'
            'Operator: ${train.operator?.name}\n'
            'dist: ${distance.round()}km  pts: ${train.points}  dur: $duration\n'
            '-> [$arrivalTime] ($remainingDuration) ${train.destination?.name} pl. ${train.destination?.arrivalPlatformReal ?? train.destination?.arrivalPlanned ?? ''}',
      )
    ];
  }
}

class _TraewellingResponse {
  List<Data>? data;
  Links? links;
  Meta? meta;

  _TraewellingResponse({this.data, this.links, this.meta});

  _TraewellingResponse.fromJson(Map<String, dynamic> json) {
    if (json['data'] != null) {
      data = <Data>[];
      json['data'].forEach((v) {
        data!.add(new Data.fromJson(v));
      });
    }
    links = json['links'] != null ? new Links.fromJson(json['links']) : null;
    meta = json['meta'] != null ? new Meta.fromJson(json['meta']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    if (this.data != null) {
      data['data'] = this.data!.map((v) => v.toJson()).toList();
    }
    if (this.links != null) {
      data['links'] = this.links!.toJson();
    }
    if (this.meta != null) {
      data['meta'] = this.meta!.toJson();
    }
    return data;
  }
}

class Data {
  int? id;
  String? body;
  List<Null>? bodyMentions;
  int? user;
  String? username;
  String? profilePicture;
  bool? preventIndex;
  int? business;
  int? visibility;
  int? likes;
  bool? liked;
  bool? isLikable;
  Null? client;
  String? createdAt;
  Train? train;
  Null? event;
  UserDetails? userDetails;
  List<Null>? tags;

  Data(
      {this.id,
      this.body,
      this.bodyMentions,
      this.user,
      this.username,
      this.profilePicture,
      this.preventIndex,
      this.business,
      this.visibility,
      this.likes,
      this.liked,
      this.isLikable,
      this.client,
      this.createdAt,
      this.train,
      this.event,
      this.userDetails,
      this.tags});

  Data.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    body = json['body'];
    user = json['user'];
    username = json['username'];
    profilePicture = json['profilePicture'];
    preventIndex = json['preventIndex'];
    business = json['business'];
    visibility = json['visibility'];
    likes = json['likes'];
    liked = json['liked'];
    isLikable = json['isLikable'];
    client = json['client'];
    createdAt = json['createdAt'];
    train = json['train'] != null ? new Train.fromJson(json['train']) : null;
    event = json['event'];
    userDetails = json['userDetails'] != null
        ? new UserDetails.fromJson(json['userDetails'])
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['body'] = this.body;
    data['user'] = this.user;
    data['username'] = this.username;
    data['profilePicture'] = this.profilePicture;
    data['preventIndex'] = this.preventIndex;
    data['business'] = this.business;
    data['visibility'] = this.visibility;
    data['likes'] = this.likes;
    data['liked'] = this.liked;
    data['isLikable'] = this.isLikable;
    data['client'] = this.client;
    data['createdAt'] = this.createdAt;
    if (this.train != null) {
      data['train'] = this.train!.toJson();
    }
    data['event'] = this.event;
    if (this.userDetails != null) {
      data['userDetails'] = this.userDetails!.toJson();
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
  Null? manualDeparture;
  Null? manualArrival;
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
      this.manualDeparture,
      this.manualArrival,
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
    manualDeparture = json['manualDeparture'];
    manualArrival = json['manualArrival'];
    origin =
        json['origin'] != null ? new Origin.fromJson(json['origin']) : null;
    destination = json['destination'] != null
        ? new Origin.fromJson(json['destination'])
        : null;
    operator = json['operator'] != null
        ? new Operator.fromJson(json['operator'])
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['trip'] = this.trip;
    data['hafasId'] = this.hafasId;
    data['category'] = this.category;
    data['number'] = this.number;
    data['lineName'] = this.lineName;
    data['journeyNumber'] = this.journeyNumber;
    data['distance'] = this.distance;
    data['points'] = this.points;
    data['duration'] = this.duration;
    data['manualDeparture'] = this.manualDeparture;
    data['manualArrival'] = this.manualArrival;
    if (this.origin != null) {
      data['origin'] = this.origin!.toJson();
    }
    if (this.destination != null) {
      data['destination'] = this.destination!.toJson();
    }
    if (this.operator != null) {
      data['operator'] = this.operator!.toJson();
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
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['name'] = this.name;
    data['rilIdentifier'] = this.rilIdentifier;
    data['evaIdentifier'] = this.evaIdentifier;
    data['arrival'] = this.arrival;
    data['arrivalPlanned'] = this.arrivalPlanned;
    data['arrivalReal'] = this.arrivalReal;
    data['arrivalPlatformPlanned'] = this.arrivalPlatformPlanned;
    data['arrivalPlatformReal'] = this.arrivalPlatformReal;
    data['departure'] = this.departure;
    data['departurePlanned'] = this.departurePlanned;
    data['departureReal'] = this.departureReal;
    data['departurePlatformPlanned'] = this.departurePlatformPlanned;
    data['departurePlatformReal'] = this.departurePlatformReal;
    data['platform'] = this.platform;
    data['isArrivalDelayed'] = this.isArrivalDelayed;
    data['isDepartureDelayed'] = this.isDepartureDelayed;
    data['cancelled'] = this.cancelled;
    return data;
  }
}

class Operator {
  int? id;
  String? identifier;
  String? name;

  Operator({this.id, this.identifier, this.name});

  Operator.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    identifier = json['identifier'];
    name = json['name'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['identifier'] = this.identifier;
    data['name'] = this.name;
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
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['displayName'] = this.displayName;
    data['username'] = this.username;
    data['profilePicture'] = this.profilePicture;
    data['mastodonUrl'] = this.mastodonUrl;
    data['preventIndex'] = this.preventIndex;
    return data;
  }
}

class Links {
  String? first;
  Null? last;
  Null? prev;
  String? next;

  Links({this.first, this.last, this.prev, this.next});

  Links.fromJson(Map<String, dynamic> json) {
    first = json['first'];
    last = json['last'];
    prev = json['prev'];
    next = json['next'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['first'] = this.first;
    data['last'] = this.last;
    data['prev'] = this.prev;
    data['next'] = this.next;
    return data;
  }
}

class Meta {
  int? currentPage;
  int? from;
  String? path;
  int? perPage;
  int? to;

  Meta({this.currentPage, this.from, this.path, this.perPage, this.to});

  Meta.fromJson(Map<String, dynamic> json) {
    currentPage = json['current_page'];
    from = json['from'];
    path = json['path'];
    perPage = json['per_page'];
    to = json['to'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['current_page'] = this.currentPage;
    data['from'] = this.from;
    data['path'] = this.path;
    data['per_page'] = this.perPage;
    data['to'] = this.to;
    return data;
  }
}
