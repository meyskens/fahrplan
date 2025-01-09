import 'dart:convert';
import 'dart:typed_data';

import 'package:fahrplan/models/g1/commands.dart';
import 'package:hive/hive.dart';

class G1Setup {
  bool calendarEnable;
  bool callEnable;
  bool msgEnable;
  bool iosMailEnable;
  App app;

  static G1Setup generateSetup() {
    final appBox = Hive.box('fahrplanNotificationApps');
    final selectedMap = appBox.toMap();
    selectedMap.removeWhere((k, v) => !v);
    final selected = selectedMap.keys.toList();

    final appList = <AppItem>[];
    for (var app in selected) {
      appList.add(AppItem(id: app, name: app));
    }

    return G1Setup(
      calendarEnable: true,
      callEnable: true,
      msgEnable: true,
      iosMailEnable: true,
      app: App(list: appList, enable: true),
    );
  }

  G1Setup(
      {required this.calendarEnable,
      required this.callEnable,
      required this.msgEnable,
      required this.iosMailEnable,
      required this.app});

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['calendar_enable'] = calendarEnable;
    data['call_enable'] = callEnable;
    data['msg_enable'] = msgEnable;
    data['ios_mail_enable'] = iosMailEnable;
    data['app'] = app.toJson();
    return data;
  }

  Uint8List toBytes() {
    return Uint8List.fromList(utf8.encode(jsonEncode(toJson())));
  }

  Future<List<Uint8List>> constructSetup() async {
    Uint8List jsonBytes = toBytes();

    int maxChunkSize = 180 - 4; // Subtract 4 bytes for header
    List<Uint8List> chunks = [];

    for (int i = 0; i < jsonBytes.length; i += maxChunkSize) {
      int end = (i + maxChunkSize < jsonBytes.length)
          ? i + maxChunkSize
          : jsonBytes.length;
      chunks.add(jsonBytes.sublist(i, end));
    }

    int totalChunks = chunks.length;
    List<Uint8List> encodedChunks = [];
    for (int index = 0; index < chunks.length; index++) {
      List<int> header = [Commands.SETUP, totalChunks, index];
      Uint8List encodedChunk = Uint8List.fromList(header + chunks[index]);
      encodedChunks.add(encodedChunk);
    }
    return encodedChunks;
  }
}

class App {
  List<AppItem>? list;
  bool? enable;

  App({this.list, this.enable});

  App.fromJson(Map<String, dynamic> json) {
    if (json['list'] != null) {
      list = <AppItem>[];
      json['list'].forEach((v) {
        list!.add(AppItem.fromJson(v));
      });
    }
    enable = json['enable'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (list != null) {
      data['list'] = list!.map((v) => v.toJson()).toList();
    }
    data['enable'] = enable;
    return data;
  }
}

class AppItem {
  String? id;
  String? name;

  AppItem({this.id, this.name});

  AppItem.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['name'] = name;
    return data;
  }
}
