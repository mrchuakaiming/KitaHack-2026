import 'dart:async';
import 'dart:convert';
import 'dart:html';
import 'package:http/http.dart' as http;
import 'package:google_maps/google_maps.dart' as gmaps;

/// MapsService
///
/// Handles all Google Maps functionality for the client-side web app (UI).
/// This service **does not contain any API keys**, the server handles AI recommendations securely.
///
/// ----------------------------
/// USAGE / FUNCTION GUIDE
/// ----------------------------
/// 1. Initialize the map on page load:
///    `initMap(mapElementId)`
///
/// 2. User searches for restaurants (directly on the map):
///    `searchRestaurants(query)`
///    - Uses Google Maps JS SDK
///    - Returns a list of { name, placeId, location }
///    - **Called when user types a search query in UI**
///
/// 3. Show AI recommendation:
///    `showAIRecommendation(recommendedPlaceId: "xyz")`
///    - Fetches full place details from the server using placeId
///    - Adds a marker to the map and centers it
///    - **Called when AI sends back recommendedPlaceId**
///
/// 4. Get full place details from server (internal for AI recommendation):
///    `getPlaceDetailsFromServer(placeId)`
///    - Calls server endpoint `/maps/place/{placeId}`
///    - Returns lat/lng and optional name
///    - **Called automatically inside showAIRecommendation**
///
/// ----------------------------
/// NOTES
/// ----------------------------
/// - User searches should **always use `searchRestaurants`** (client-side, instant results)
/// - AI recommendations should **always call `showAIRecommendation`**
///   to fetch secure data from server (server has API key)
/// - No server calls for normal user searches, all displayed directly in the map
/// - Markers are clickable, open Google Maps in new tab

class MapsService {
  gmaps.GMap? _map;
  gmaps.PlacesService? _placesService;
  final List<gmaps.Marker> _markers = [];
  gmaps.Marker? _aiMarker;

  final String serverBaseUrl; // e.g., "https://your-server.com"

  MapsService({required this.serverBaseUrl});

  /// ----------------------------
  /// MAP INITIALIZATION (UI)
  /// ----------------------------
  void initMap(String mapElementId,
      {double lat = 3.1390, double lng = 101.6869, int zoom = 12}) {
    final mapOptions = gmaps.MapOptions()
      ..center = gmaps.LatLng(lat, lng)
      ..zoom = zoom;

    _map = gmaps.GMap(document.getElementById(mapElementId)!, mapOptions);
    _placesService = gmaps.PlacesService(_map!);
  }

  /// ----------------------------
  /// CLIENT-SIDE SEARCH FOR USER (Google Maps JS SDK)
  /// ----------------------------
  Future<List<Map<String, dynamic>>> searchRestaurants(String query) async {
    if (_placesService == null) return [];

    final completer = Completer<List<Map<String, dynamic>>>();
    final request = gmaps.TextSearchRequest()
      ..query = query
      ..type = 'restaurant';

    _placesService!.textSearch(request, (results, status) {
      if (status == gmaps.PlacesServiceStatus.OK && results != null) {
        final places = results.map((p) {
          return {
            "name": p.name ?? "",
            "placeId": p.placeId ?? "",
            "location":
                "${p.geometry?.location?.lat ?? 0.0},${p.geometry?.location?.lng ?? 0.0}",
          };
        }).toList();
        completer.complete(places);
      } else {
        completer.complete([]);
      }
    });

    return completer.future;
  }

  /// ----------------------------
  /// SHOW AI RECOMMENDATION (SERVER-SIDE)
  /// ----------------------------
  Future<void> showAIRecommendation({
    String? recommendedPlaceId,
    String placeName = "AI Recommendation",
  }) async {
    if (_map == null) return;
    _clearMarkers();

    if (recommendedPlaceId != null) {
      // Get full details from server (lat/lng, name)
      final location = await getPlaceDetailsFromServer(recommendedPlaceId);
      if (location != null) {
        _addMarker(location["lat"], location["lng"], location["name"] ?? placeName);
        _map!.center = gmaps.LatLng(location["lat"], location["lng"]);
        _map!.zoom = 15;
      }
    }
  }

  /// ----------------------------
  /// SERVER-SIDE API CALL
  /// ----------------------------
  Future<Map<String, dynamic>?> getPlaceDetailsFromServer(String placeId) async {
    try {
      final url = Uri.parse("$serverBaseUrl/maps/place/$placeId");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          "lat": data["lat"],
          "lng": data["lng"],
          "name": data["name"] ?? "",
        };
      }
    } catch (e) {
      print("[ERROR] getPlaceDetailsFromServer failed: $e");
    }
    return null;
  }

  /// ----------------------------
  /// PRIVATE UI FUNCTIONS
  /// ----------------------------
  void _addMarker(double lat, double lng, String title) {
    final position = gmaps.LatLng(lat, lng);
    final marker = gmaps.Marker(gmaps.MarkerOptions()
      ..position = position
      ..map = _map
      ..title = title
      ..clickable = true);

    marker.onClick.listen((_) {
      final url = "https://www.google.com/maps/search/?api=1&query=$lat,$lng";
      window.open(url, "_blank");
    });

    _markers.add(marker);
  }

  void _clearMarkers() {
    for (var marker in _markers) {
      marker.map = null;
    }
    _markers.clear();
    _aiMarker?.map = null;
  }
}
