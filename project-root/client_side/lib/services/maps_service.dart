import 'dart:async';
import 'dart:html';
import 'package:google_maps/google_maps.dart' as gmaps;

/// MapsService
///
/// Handles all Google Maps functionality for the client-side web app.
///
/// **Responsibilities:**
/// - Embed Google Maps in the HTML page.
/// - Display AI recommendations or user search results.
/// - Allow user to search for restaurants and select them.
/// - Track markers and allow clicking to open Google Maps web/app.
///
/// **Usage / Flow for UI/ViewModel:**
/// 1. `initMap(mapElementId)` → initialize map.
/// 2. `showAIRecommendation(...)` → display AI recommendation.
/// 3. `searchRestaurants(query)` → return restaurant list for UI to show.
/// 4. `getPlaceDetails(placeId)` → return coordinates, optional price/cuisine.
/// 5. Markers are clickable → open Google Maps.
class MapsService {
  gmaps.GMap? _map;
  gmaps.PlacesService? _placesService;

  final List<gmaps.Marker> _markers = [];
  gmaps.Marker? _aiMarker;

  /// Initialize Google Map inside the HTML element.
  void initMap(String mapElementId,
      {double lat = 3.1390, double lng = 101.6869, int zoom = 12}) {
    final mapOptions = gmaps.MapOptions()
      ..center = gmaps.LatLng(lat, lng)
      ..zoom = zoom;

    _map = gmaps.GMap(document.getElementById(mapElementId)!, mapOptions);
    _placesService = gmaps.PlacesService(_map!);
  }

  /// Show AI recommendation on the map.
  ///
  /// Either `recommendedPlaceId` or `recommendedCuisine` should be provided.
  Future<void> showAIRecommendation({
    String? recommendedPlaceId,
    String? recommendedCuisine,
    String placeName = "AI Recommendation",
  }) async {
    if (_map == null || _placesService == null) return;

    _clearMarkers();

    if (recommendedPlaceId != null) {
      final location = await _getLatLngFromPlaceId(recommendedPlaceId);
      if (location != null) {
        _addMarker(location["lat"]!, location["lng"]!, placeName);
        _map!.center = gmaps.LatLng(location["lat"]!, location["lng"]!);
        _map!.zoom = 15;
      }
    } else if (recommendedCuisine != null) {
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

  /// User search for restaurants
  ///
  /// Returns list of maps with:
  /// - "name"
  /// - "placeId"
  /// - "location" ("lat,lng")
  /// Optional: priceLevel, cuisineLabels (commented, requires extra API)
  Future<List<Map<String, dynamic>>> searchRestaurants(String query) async {
    if (_map == null || _placesService == null) return [];

    final results = await _textSearchHidden(query);

    // Add optional placeholders for price and cuisine
    return results.map((r) {
      return {
        "name": r["name"],
        "placeId": r["placeId"],
        "location": r["location"],
        // "priceLevel": await getPriceLevel(r["placeId"]), // optional, need extra call
        // "cuisineLabels": await getCuisineLabels(r["placeId"]), // optional, external API
      };
    }).toList();
  }

  /// Get coordinates and optional details from Place ID
  Future<Map<String, dynamic>?> getPlaceDetails(String placeId) async {
    final latLng = await _getLatLngFromPlaceId(placeId);
    if (latLng == null) return null;

    // Optional: price level or cuisine can be fetched here
    return {
      "placeId": placeId,
      "lat": latLng["lat"],
      "lng": latLng["lng"],
      // "priceLevel": await getPriceLevel(placeId), // optional
      // "cuisineLabels": await getCuisineLabels(placeId), // optional
    };
  }

  /// -----------------------------
  /// PRIVATE / INTERNAL
  /// -----------------------------

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

  Future<Map<String, double>?> _getLatLngFromPlaceId(String placeId) {
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
