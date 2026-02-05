import 'dart:async';
import 'dart:convert';
import 'dart:html';
import 'package:http/http.dart' as http;
import 'package:google_maps/google_maps.dart' as gmaps;

/// MapsService
///
/// Handles all Google Maps functionality for the client-side web app (UI).
/// This service **does not contain any API keys**.
/// All Google Maps Web API calls are handled by the server.
///
/// ----------------------------
/// USAGE / FUNCTION GUIDE
/// ----------------------------
/// 1. Initialize the map on page load:
///    `initMap(mapElementId)`
///
/// 2. User searches for restaurants:
///    `searchRestaurants(query)`
///    - Calls server endpoint
///    - Returns a list of { name, placeId, lat, lng }
///    - **Called when user types a search query in UI**
///
/// 3. Show AI recommendation:
///    `showAIRecommendation(recommendedPlaceId)`
///    - Fetches full place details from the server using placeId
///    - Adds a marker to the map and centers it
///    - **Called when AI sends back recommendedPlaceId**
///
/// 4. Get full place details from server (internal for AI recommendation):
///    `getPlaceDetails(placeId)`
///    - Calls server endpoint `/maps/place/{placeId}`
///    - Returns lat/lng and optional name
///
/// ----------------------------
/// NOTES
/// ----------------------------
/// - This file NEVER calls Google Maps Web APIs
/// - This file NEVER uses an API key
/// - Server decides WHAT data to return
/// - Client decides HOW to display it

class MapsService {
  gmaps.GMap? _map;
  final List<gmaps.Marker> _markers = [];

  final String serverBaseUrl; // e.g. https://your-server.com

  MapsService({required this.serverBaseUrl});

  /// ----------------------------
  /// MAP INITIALIZATION (UI)
  /// ----------------------------
  void initMap(
    String mapElementId, {
    double lat = 3.1390,
    double lng = 101.6869,
    int zoom = 12,
  }) {
    final mapOptions = gmaps.MapOptions()
      ..center = gmaps.LatLng(lat, lng)
      ..zoom = zoom;

    _map = gmaps.GMap(
      document.getElementById(mapElementId)!,
      mapOptions,
    );
  }

  /// ----------------------------
  /// USER SEARCH (SERVER-SIDE)
  /// ----------------------------
  Future<List<Map<String, dynamic>>> searchRestaurants(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final url = Uri.parse("$serverBaseUrl/maps/search");
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"query": query}),
      );

      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body) as List<dynamic>;

      _clearMarkers();

      final results = data.map<Map<String, dynamic>>((e) {
        final lat = e["lat"];
        final lng = e["lng"];
        final name = e["name"] ?? "";

        _addMarker(lat, lng, name);

        return {
          "name": name,
          "placeId": e["placeId"],
          "lat": lat,
          "lng": lng,
        };
      }).toList();

      return results;
    } catch (e) {
      print("[ERROR] searchRestaurants failed: $e");
      return [];
    }
  }

  /// ----------------------------
  /// SHOW AI RECOMMENDATION (SERVER-SIDE)
  /// ----------------------------
  Future<void> showAIRecommendation({
    required String recommendedPlaceId,
    String placeNameFallback = "AI Recommendation",
  }) async {
    if (_map == null) return;

    _clearMarkers();

    final details = await getPlaceDetails(recommendedPlaceId);
    if (details == null) return;

    final lat = details["lat"];
    final lng = details["lng"];
    final name = details["name"] ?? placeNameFallback;

    _addMarker(lat, lng, name);
    _map!
      ..center = gmaps.LatLng(lat, lng)
      ..zoom = 15;
  }

  /// ----------------------------
  /// SERVER-SIDE API CALL
  /// ----------------------------
  Future<Map<String, dynamic>?> getPlaceDetails(String placeId) async {
    try {
      final url = Uri.parse("$serverBaseUrl/maps/place/$placeId");
      final response = await http.get(url);

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      return {
        "placeId": placeId,
        "name": data["name"],
        "lat": data["lat"],
        "lng": data["lng"],
      };
    } catch (e) {
      print("[ERROR] getPlaceDetails failed: $e");
      return null;
    }
  }

  /// ----------------------------
  /// PRIVATE UI FUNCTIONS
  /// ----------------------------
  void _addMarker(double lat, double lng, String title) {
    final position = gmaps.LatLng(lat, lng);

    final marker = gmaps.Marker(
      gmaps.MarkerOptions()
        ..position = position
        ..map = _map
        ..title = title
        ..clickable = true,
    );

    marker.onClick.listen((_) {
      final url =
          "https://www.google.com/maps/search/?api=1&query=$lat,$lng";
      window.open(url, "_blank");
    });

    _markers.add(marker);
  }

  void _clearMarkers() {
    for (final marker in _markers) {
      marker.map = null;
    }
    _markers.clear();
  }
}
