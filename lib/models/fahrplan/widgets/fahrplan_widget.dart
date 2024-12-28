import 'package:fahrplan/models/g1/note.dart';

abstract class FahrplanWidget {
  int getPriority();
  Future<List<Note>> generateDashboardItems() {
    throw UnimplementedError();
  }
}
