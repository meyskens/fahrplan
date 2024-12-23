import 'package:google_maps_flutter/google_maps_flutter.dart' as maps;

List<maps.LatLng> decodePolyline(String polyline) {
  List<maps.LatLng> points = [];
  int index = 0;
  int len = polyline.length;
  int lat = 0;
  int lng = 0;

  while (index < len) {
    int b, shift = 0, result = 0;
    do {
      b = polyline.codeUnitAt(index++) - 63;
      result |= (b & 0x1F) << shift;
      shift += 5;
    } while (b >= 0x20);
    int dlat = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
    lat += dlat;

    shift = 0;
    result = 0;
    do {
      b = polyline.codeUnitAt(index++) - 63;
      result |= (b & 0x1F) << shift;
      shift += 5;
    } while (b >= 0x20);
    int dlng = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
    lng += dlng;

    points.add(maps.LatLng(lat / 1E5, lng / 1E5));
  }

  return points;
}
