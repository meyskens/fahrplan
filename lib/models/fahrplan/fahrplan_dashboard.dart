import 'package:fahrplan/models/fahrplan/daily.dart';
import 'package:fahrplan/models/fahrplan/stop.dart';
import 'package:fahrplan/models/fahrplan/widgets/fahrplan_widget.dart';
import 'package:fahrplan/models/fahrplan/widgets/traewelling.dart';
import 'package:fahrplan/models/g1/note.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

class FahrplanItem {
  final String title;
  final int? hour;
  final int? minute;

  FahrplanItem({
    required this.title,
    this.hour,
    this.minute,
  });

  @override
  String toString() {
    return '${NoteSupportedIcons.CHECKBOX}${hour?.toString().padLeft(2, '0') ?? ''}:${minute?.toString().padLeft(2, '0') ?? ''} $title';
  }
}

class FahrplanDashboard {
  static final FahrplanDashboard _singleton = FahrplanDashboard._internal();
  factory FahrplanDashboard() {
    return _singleton;
  }
  FahrplanDashboard._internal();

  List<FahrplanItem> items = [];

  List<FahrplanWidget> widgets = [
    TraewellingWidget(),
  ];

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    await Hive.openBox<FahrplanDailyItem>('fahrplanDailyBox');
    try {
      await Hive.openLazyBox<FahrplanStopItem>('fahrplanStopBox');
    } catch (e) {
      debugPrint('Error while registering adapter: $e');
    }

    _initialized = true;
  }

  bool _isToday(DateTime time) {
    final now = DateTime.now();
    return time.year == now.year &&
        time.month == now.month &&
        time.day == now.day;
  }

  Future<void> _loadItems() async {
    await initialize();
    items.clear();

    final fahrplanDailyBox = Hive.box<FahrplanDailyItem>('fahrplanDailyBox');
    items.addAll(fahrplanDailyBox.values.map((e) => e.toFahrplanItem()));

    final fahrplanStopBox = Hive.lazyBox<FahrplanStopItem>('fahrplanStopBox');
    final List<FahrplanStopItem> stops = [];
    for (var i = 0; i < fahrplanStopBox.length; i++) {
      final item = await fahrplanStopBox.getAt(i);
      if (item != null) {
        stops.add(item);
      }
    }
    final todayStops = stops
        .where((element) =>
            _isToday(element.time) && element.time.isAfter(DateTime.now()))
        .toList();
    items.addAll(todayStops.map((e) => e.toFahrplanItem()));
  }

  Future<List<Note>> generateDashboardItems() async {
    await _loadItems();
    _sortItemsByTime();

    widgets.sort((a, b) => a.getPriority().compareTo(b.getPriority()));

    final List<Note> notes = _turnItemsIntoNotes();
    debugPrint('Got ${notes.length} notes from items');
    final List<Note> widgetNotes = [];

    for (var widget in widgets) {
      try {
        widgetNotes.addAll(await widget.generateDashboardItems());
      } catch (e) {
        debugPrint('Error while generating widget notes: $e');
      }
    }
    debugPrint('Got ${widgetNotes.length} notes from widgets');
    widgetNotes.addAll(notes);

    // if there are more than 4 notes, only show the first 4
    if (widgetNotes.length > 4) {
      widgetNotes.removeRange(4, widgetNotes.length);
    }

    // set the note indexes to 1, 2, 3, 4
    for (var i = 0; i < widgetNotes.length; i++) {
      widgetNotes[i].noteNumber = i + 1;
    }

    return widgetNotes;
  }

  void _sortItemsByTime() {
    final now = DateTime.now();

    items.sort((a, b) {
      if (a.hour == null || a.minute == null) {
        return 1;
      }
      if (b.hour == null || b.minute == null) {
        return -1;
      }

      final aTime = DateTime(now.year, now.month, now.day, a.hour!, a.minute!);
      final bTime = DateTime(now.year, now.month, now.day, b.hour!, b.minute!);

      return aTime.compareTo(bTime);
    });
  }

  List<Note> _turnItemsIntoNotes() {
    final List<Note> notes = [];

    final now = DateTime.now();
    final futureItems = <FahrplanItem>[];

    for (var fpi in items) {
      if (fpi.hour != null && fpi.minute != null) {
        final itemTime =
            DateTime(now.year, now.month, now.day, fpi.hour!, fpi.minute!);
        if (itemTime.isAfter(now)) {
          futureItems.add(fpi);
        }
      }
    }

    // devide into lists of 4
    final List<List<FahrplanItem>> chunks = [];
    int chunkIndex = 0;
    for (var i = 0; i < futureItems.length; i++) {
      if (i % 4 == 0) {
        chunks.add([]);
        chunkIndex++;
      }
      chunks[chunkIndex - 1].add(futureItems[i]);
    }

    // generate notes for the first 4 chunks
    for (var i = 0; i < chunks.length && i < 4; i++) {
      final chunk = chunks[i];
      final note = Note(
        noteNumber: i + 1,
        name: 'Fahrplan',
        text: chunk.map((e) => e.toString()).join('\n'),
      );
      notes.add(note);
    }

    return notes;
  }
}
