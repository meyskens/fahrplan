import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart' as places_sdk;

// Replace with your API key
final places = places_sdk.FlutterGooglePlacesSdk('AIzaSyDNkyfweMy-wKaBHjMjDWT8IDx4pWXBo0g');

Future<List<dynamic>> getPlaceSuggestions(String query) async {
  if (query.isEmpty) {
    return ["Current Location"];
  }

  final result = await places.findAutocompletePredictions(query);
  return ["Current Location", ...result.predictions];
}

Future<places_sdk.Place?> getPlaceDetails(String placeId) async {
  final details = await places.fetchPlace(
    placeId,
    fields: [places_sdk.PlaceField.Location, places_sdk.PlaceField.Name, places_sdk.PlaceField.Address],
  );
  return details.place;
}
