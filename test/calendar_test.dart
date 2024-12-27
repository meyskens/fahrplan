import 'package:flutter_test/flutter_test.dart';
import 'package:fahrplan/models/g1/calendar.dart';
import 'dart:typed_data';

void main() {
  group('CalendarItem', () {
    test('constructDashboardCalendarItem returns correct Uint8List', () {
      final calendarItem = CalendarItem(
        name: 'Test G1',
        time: '13:30-14:30',
        location: 'Home',
      );

      final result = calendarItem.constructDashboardCalendarItem();

      final expectedBytes = [
        0x06, 0x29, // Header
        0x00, 0x6d, 0x03, 0x01, 0x00, 0x01, 0x00, 0x00, 0x00, 0x03, 0x01, 0x01,
        0x07, // Fixed bytes
        0x54, 0x65, 0x73, 0x74, 0x20, 0x47, 0x31, // 'Test G1'
        0x02, 0x0B, // Separators
        0x31, 0x33, 0x3A, 0x33, 0x30, 0x2D, 0x31, 0x34, 0x3A, 0x33,
        0x30, // '13:30-14:30'
        0x03, 0x04, // Separators
        0x48, 0x6F, 0x6D, 0x65, // 'Home'
      ];

      expect(result, equals(Uint8List.fromList(expectedBytes)));
    });
  });
}
