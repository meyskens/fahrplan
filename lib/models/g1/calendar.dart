import 'dart:convert';
import 'dart:typed_data';

class CalendarItem {
  String name;
  String time;
  String location;

  CalendarItem({
    required this.name,
    required this.time,
    required this.location,
  });

  Uint8List constructDashboardCalendarItem() {
    List<int> bytes = [
      0x00, // Fixed byte
      0x6d, // Fixed byte
      0x03, // Fixed byte
      0x01, // Fixed byte
      0x00, // Fixed byte
      0x01, // Fixed byte
      0x00, // Fixed byte
      0x00, // Fixed byte
      0x00, // Fixed byte
      0x03, // Fixed byte
      0x01, // Fixed byte
    ];

    bytes.add(0x01); // name of the event
    bytes.add(name.length); // length
    bytes.addAll(utf8.encode(name));
    bytes.add(0x02); // time of event
    bytes.add(time.length); // Separator
    bytes.addAll(utf8.encode(time));
    bytes.add(0x03); // location of event
    bytes.add(location.length); // length
    bytes.addAll(utf8.encode(location));

    final length = bytes.length + 2;
    List<int> header = [0x06, length];
    return Uint8List.fromList(header + bytes);
  }
}
