import 'dart:async';
import 'dart:html';
import 'package:google_maps/google_maps.dart' as gmaps;

/// MapsService
///
/// Handles all Google Maps functionality for the client-side web app.
///
/// **Responsibilities:**
/// - Embed Google Maps in the HTML page.
/// - Display AI recommendations (single place ID or cuisine type search).
/// - Allow user to search for restaurants and select them.
/// - Track markers and allow clicking to open Google Maps web/app.
///
/// **Usage / Flow:**
/// 1. `initMap(mapElementId)` → initialize map in HTML container.
/// 2. `showAIRecommendation(...)` → display AI recommendations.
/// 3. `searchRestaurants(query)` → allow user search for restaurants.
/// 4. `getPlaceDetails(placeId)` → get coordinates for a place (AI or user selected).
/// 5. Markers are clickable → open Google Maps in new tab.
class MapsService {
  gmaps.GMap? _map;
  gmaps.PlacesService? _placesService;

  /// List of markers for user selection or hidden search
  List<gmaps.Marker> _markers = [];

  /// Marker for AI-recommended place
  gmaps.Marker? _aiMarker;

  /// Initialize Google Map inside the HTML element.
  ///
  /// Defaults to Kuala Lumpur if coordinates not provided.
  void initMap(String mapElementId,
      {double lat = 3.1390, double lng = 101.6869, int zoom = 12}) {
    final mapOptions = gmaps.MapOptions()
      ..center = gmaps.LatLng(lat, lng)
      ..zoom = zoom;

    _map = gmaps.GMap(document.getElementById(mapElementId)!, mapOptions);
    _placesService = gmaps.PlacesService(_map!);
  }

  /// Show AI recommendation on the embedded map.
  ///
  /// - If `recommendedPlaceId` is provided → show single marker.
  /// - If only `recommendedCuisine` is provided → perform hidden search globally.
  /// - Center map accordingly.
  Future<void> showAIRecommendation({
    String? recommendedPlaceId,
    String? recommendedCuisine,
    String placeName = "AI Recommendation",
  }) async {
    if (_map == null || _placesService == null) return;

    // Clear previous markers
    _clearMarkers();

    if (recommendedPlaceId != null) {
      // Show single AI marker
      final location = await _getLatLngFromPlaceId(recommendedPlaceId);
      if (location != null) {
        _addMarker(location["lat"]!, location["lng"]!, placeName);
        _map!.center = gmaps.LatLng(location["lat"]!, location["lng"]!);
        _map!.zoom = 15;
      }
    } else if (recommendedCuisine != null) {
      // Hidden global search for AI cuisine recommendation
      final results = await _textSearchHidden("$recommendedCuisine restaurant");

      for (var result in results) {
        final locParts = result["location"]!.split(",");
        final resLat = double.parse(locParts[0]);
        final resLng = double.parse(locParts[1]);
        _addMarker(resLat, resLng, result["name"]!);
      }

      if (results.isNotEmpty) {
        final first = results.first;
        final latLng = first["location"]!.split(",");
        _map!.center = gmaps.LatLng(
          double.parse(latLng[0]),
          double.parse(latLng[1]),
        );
        _map!.zoom = 13;
      }
    }
  }

  /// Perform user-driven search (returns list of restaurant results for selection).
  ///
  /// Example:
  /// ```
  /// final results = await mapsService.searchRestaurants("Italian near me");
  /// ```
  Future<List<Map<String, String>>> searchRestaurants(String query) async {
    if (_map == null || _placesService == null) return [];

    final results = await _textSearchHidden(query);
    // UI can show this list; user selects one → get Place ID
    return results;
  }

  /// Get coordinates from a Place ID
  Future<Map<String, double>?> getPlaceDetails(String placeId) async {
    return _getLatLngFromPlaceId(placeId);
  }

  /// -----------------------------
  /// INTERNAL / PRIVATE METHODS
  /// -----------------------------

  /// Add marker to the map
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

  /// Clear all markers (including AI marker)
  void _clearMarkers() {
    for (var marker in _markers) {
      marker.map = null;
    }
    _markers.clear();
    _aiMarker?.map = null;
  }

  /// Hidden Text Search using Google Places API
  Future<List<Map<String, String>>> _textSearchHidden(String query) {
    final completer = Completer<List<Map<String, String>>>();

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

  /// Get latitude/longitude from Place ID
  Future<Map<String, double>?> _getLatLngFromPlaceId(String placeId) async {
    final completer = Completer<Map<String, double>?>();
    final request = gmaps.PlaceDetailsRequest()..placeId = placeId;

    _placesService!.getDetails(request, (place, status) {
      if (status == gmaps.PlacesServiceStatus.OK && place != null) {
        final lat = place.geometry?.location?.lat ?? 0.0;
        final lng = place.geometry?.location?.lng ?? 0.0;
        completer.complete({"lat": lat, "lng": lng});
      } else {
        completer.complete(null);
      }
    });

    return completer.future;
  }
}
