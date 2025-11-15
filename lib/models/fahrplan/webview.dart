import 'dart:async';

import 'package:fahrplan/models/fahrplan/widgets/fahrplan_widget.dart';
import 'package:fahrplan/models/g1/note.dart';
import 'package:flutter/material.dart';
import 'package:fuzzywuzzy/fuzzywuzzy.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;

part 'webview.g.dart';

enum RefreshInterval {
  tenSeconds,
  thirtySeconds,
  sixtySeconds,
}

extension RefreshIntervalExtension on RefreshInterval {
  int get seconds {
    switch (this) {
      case RefreshInterval.tenSeconds:
        return 10;
      case RefreshInterval.thirtySeconds:
        return 30;
      case RefreshInterval.sixtySeconds:
        return 60;
    }
  }

  String get displayName {
    switch (this) {
      case RefreshInterval.tenSeconds:
        return '10 seconds';
      case RefreshInterval.thirtySeconds:
        return '30 seconds';
      case RefreshInterval.sixtySeconds:
        return '60 seconds';
    }
  }

  static RefreshInterval fromSeconds(int seconds) {
    switch (seconds) {
      case 10:
        return RefreshInterval.tenSeconds;
      case 30:
        return RefreshInterval.thirtySeconds;
      case 60:
        return RefreshInterval.sixtySeconds;
      default:
        return RefreshInterval.thirtySeconds;
    }
  }
}

@HiveType(typeId: 5)
class FahrplanWebView extends FahrplanWidget {
  @HiveField(0)
  late String uuid;

  @HiveField(1)
  String name;

  @HiveField(2)
  String url;

  @HiveField(3)
  int refreshIntervalSeconds;

  @HiveField(4)
  bool isShown;

  @HiveField(5)
  String? cachedContent;

  @HiveField(6)
  DateTime? lastFetched;

  @HiveField(7)
  String? customTitle;

  Timer? _refreshTimer;

  @override
  int getPriority() {
    return 2; // Same priority as checklists
  }

  static List<String> getAllWebViewNames() {
    final box = Hive.box<FahrplanWebView>('fahrplanWebViewBox');
    return box.values.map((wv) => wv.name).toList();
  }

  static int _getBestMatchIndex(String name) {
    final box = Hive.box<FahrplanWebView>('fahrplanWebViewBox');
    final allWebViews = box.values.toList();
    int maxScore = 0;
    int index = -1;
    for (final webView in allWebViews) {
      final score = ratio(name.toLowerCase(), webView.name.toLowerCase());
      debugPrint('Score for $name and ${webView.name}: $score');
      if (score > maxScore) {
        maxScore = score;
        index = allWebViews.indexOf(webView);
      }
    }
    if (maxScore > 70) {
      return index;
    }
    return -1;
  }

  static FahrplanWebView? displayWebViewFor(String name) {
    final bestMatchIndex = _getBestMatchIndex(name);
    if (bestMatchIndex == -1) {
      return null;
    }
    final box = Hive.box<FahrplanWebView>('fahrplanWebViewBox');
    final bestMatch = box.getAt(bestMatchIndex);
    if (bestMatch != null) {
      bestMatch.show();
      box.putAt(bestMatchIndex, bestMatch);
      return bestMatch;
    }
    return null;
  }

  static FahrplanWebView? hideWebViewFor(String name) {
    final bestMatchIndex = _getBestMatchIndex(name);
    if (bestMatchIndex == -1) {
      return null;
    }
    final box = Hive.box<FahrplanWebView>('fahrplanWebViewBox');
    final bestMatch = box.getAt(bestMatchIndex);
    if (bestMatch != null) {
      bestMatch.hide();
      box.putAt(bestMatchIndex, bestMatch);
      return bestMatch;
    }
    return null;
  }

  FahrplanWebView({
    required this.name,
    required this.url,
    required this.refreshIntervalSeconds,
    this.isShown = false,
    this.cachedContent,
    this.lastFetched,
    this.customTitle,
    String? uuid,
  }) {
    this.uuid = uuid ?? Uuid().v4();
  }

  RefreshInterval get refreshInterval {
    return RefreshIntervalExtension.fromSeconds(refreshIntervalSeconds);
  }

  void setRefreshInterval(RefreshInterval interval) {
    refreshIntervalSeconds = interval.seconds;
  }

  void show() {
    isShown = true;
    _startRefreshTimer();
  }

  void hide() {
    isShown = false;
    _stopRefreshTimer();
  }

  void _startRefreshTimer() {
    _stopRefreshTimer();
    _refreshTimer = Timer.periodic(
      Duration(seconds: refreshIntervalSeconds),
      (_) => fetchContent(),
    );
    // Fetch immediately when showing
    fetchContent();
  }

  void _stopRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  Future<void> fetchContent() async {
    try {
      debugPrint('Fetching content from $url');
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        cachedContent = response.body;
        lastFetched = DateTime.now();

        // Check for custom title header
        if (response.headers.containsKey('fahrplan-title')) {
          customTitle = response.headers['fahrplan-title'];
        } else {
          customTitle = null;
        }

        // Save to Hive
        final box = Hive.box<FahrplanWebView>('fahrplanWebViewBox');
        final index = box.values.toList().indexWhere((wv) => wv.uuid == uuid);
        if (index != -1) {
          box.putAt(index, this);
        }

        debugPrint('Successfully fetched content from $url');
      } else {
        debugPrint('Failed to fetch content from $url: ${response.statusCode}');
        cachedContent = 'Error: HTTP ${response.statusCode}';
      }
    } catch (e) {
      debugPrint('Error fetching content from $url: $e');
      cachedContent = 'Error: $e';
    }
  }

  @override
  Future<List<Note>> generateDashboardItems() async {
    if (!isShown || cachedContent == null || cachedContent!.isEmpty) {
      return [];
    }

    final notes = <Note>[];
    final lines = cachedContent!.split('\n');

    // Paginate content with 4 lines per page
    for (int i = 0; i < lines.length; i += 4) {
      List<String> pageLines = [];
      for (int j = 0; j < 4 && (i + j) < lines.length; j++) {
        final line = lines[i + j].trim();
        if (line.isNotEmpty) {
          pageLines.add(line);
        }
      }

      if (pageLines.isEmpty) continue;

      final pageNumber = (i ~/ 4) + 1;
      final totalPages = (lines.length / 4).ceil();

      // Use custom title if available, otherwise use name + page
      final title = customTitle ?? '$name - $pageNumber/$totalPages';

      notes.add(Note(
        noteNumber: 1, // dummy
        name: title,
        text: pageLines.join('\n'),
      ));
    }

    return notes;
  }
}
