import 'dart:async';
import 'dart:html';
import 'package:google_maps/google_maps.dart' as gmaps;

/// MapsService
///
/// Handles all Google Maps functionality for the client-side web app.
///
/// **Purpose / Responsibilities:**
/// - Embed Google Maps inside the web page.
/// - Allow AI or user to show recommendations on the map.
/// - Perform hidden search for AI-recommended cuisine near host location.
/// - Add markers for restaurants (participant selections or AI recommendations).
/// - Allow clicking markers to open Google Maps in a new tab.
///
/// **Typical usage flow (embedding map and showing AI recommendation):**
/// 1. `initMap(mapElementId)` → initialize map in the HTML container.
/// 2. `showAIRecommendation(...)` → display AI recommended place or cuisine markers.
///    - Internally:
///       a. Get host location using `getHostLocation()`
///       b. Show AI place ID marker OR perform hidden cuisine search
///       c. Add clickable markers
///
/// **Markers behavior:**
/// - Only one marker for AI place ID at a time (_aiMarker)
/// - Hidden cuisine search shows full list of results (_markers list)
/// - Clicking any marker opens Google Maps web with the location
class MapsService {
  gmaps.GMap? _map;
  gmaps.PlacesService? _placesService;

  /// List of markers for hidden cuisine search
  List<gmaps.Marker> _markers = [];

  /// Marker for AI-recommended place
  gmaps.Marker? _aiMarker;

  /// Initialize Google Map inside the given HTML element.
  ///
  /// Params:
  /// - mapElementId: ID of the HTML container element
  /// - lat/lng: initial center coordinates (default: Kuala Lumpur)
  /// - zoom: initial zoom level
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
  /// Logic:
  /// - If recommendedPlaceId is provided → show a single marker.
  /// - If only recommendedCuisine is provided → perform a hidden search near host location,
  ///   show all search results as markers on the embedded map.
  ///
  /// Params:
  /// - recommendedPlaceId: AI returned Place ID (optional)
  /// - recommendedCuisine: AI returned cuisine type (optional)
  /// - placeName: marker label if Place ID exists (default: "AI Recommendation")
  /// 
  /// Usage:
  /// ```
  /// await mapsService.showAIRecommendation(
  ///   recommendedPlaceId: aiResult.recommendedPlaceId,
  ///   recommendedCuisine: aiResult.recommendedCuisine,
  /// );
  /// ```
  Future<void> showAIRecommendation({
    String? recommendedPlaceId,
    String? recommendedCuisine,
    String placeName = "AI Recommendation",
  }) async {
    if (_map == null || _placesService == null) return;

    // Clear previous markers
    for (var marker in _markers) {
      marker.map = null;
    }
    _markers.clear();
    _aiMarker?.map = null;

    // Step 1: get host location
    final hostLocation = await getHostLocation();
    final hostLat = hostLocation["lat"]!;
    final hostLng = hostLocation["lng"]!;

    // Step 2: Show AI place or perform hidden cuisine search
    if (recommendedPlaceId != null) {
      // Place ID available → show single AI marker
      final location = await _getLatLngFromPlaceId(recommendedPlaceId);
      if (location != null) {
        _addMarker(location["lat"], location["lng"], placeName);
      }
    } else if (recommendedCuisine != null) {
      // Only cuisine → hidden search for "<cuisine> near host"
      final searchResults =
          await _textSearchHidden("${recommendedCuisine} near me", hostLat, hostLng);

      // Add all results as markers
      for (var result in searchResults) {
        final locParts = result["location"].split(",");
        final resLat = double.parse(locParts[0]);
        final resLng = double.parse(locParts[1]);
        _addMarker(resLat, resLng, result["name"]);
      }

      // Optionally, center map on host location
      _map!.center = gmaps.LatLng(hostLat, hostLng);
      _map!.zoom = 13;

      /*
      // Old behavior (optional / commented):
      // Show only the first top match as marker
      if (searchResults.isNotEmpty) {
        final firstResult = searchResults.first;
        final locParts = firstResult["location"].split(",");
        final resLat = double.parse(locParts[0]);
        final resLng = double.parse(locParts[1]);
        _addMarker(resLat, resLng, firstResult["name"]);
      }
      */
    }
  }

  /// Add a marker to the map with click listener to open Google Maps web
  void _addMarker(double lat, double lng, String title) {
    final position = gmaps.LatLng(lat, lng);
    final marker = gmaps.Marker(gmaps.MarkerOptions()
      ..position = position
      ..map = _map
      ..title = title
      ..clickable = true);

    // Click opens Google Maps web
    marker.onClick.listen((_) {
      final url = "https://www.google.com/maps/search/?api=1&query=$lat,$lng";
      window.open(url, "_blank");
    });

    _markers.add(marker);
  }

  /// Hidden search for cuisine type near given coordinates
  ///
  /// Returns a list of maps with:
  /// - "name": restaurant name
  /// - "placeId": Google Maps Place ID
  /// - "location": "lat,lng" string
  Future<List<Map<String, String>>> _textSearchHidden(
      String query, double lat, double lng) {
    final completer = Completer<List<Map<String, String>>>();

    final request = gmaps.TextSearchRequest()
      ..query = query
      ..location = gmaps.LatLng(lat, lng)
      ..radius = 5000 // 5 km search radius
      ..type = 'restaurant';

    _placesService!.textSearch(request, (results, status) {
      if (status == gmaps.PlacesServiceStatus.OK && results != null) {
        final places = results.map((p) {
          return {
            "name": p.name ?? "",
            "placeId": p.placeId ?? "",
            "location":
                "${p.geometry?.location?.lat ?? lat},${p.geometry?.location?.lng ?? lng}",
          };
        }).toList();
        completer.complete(places);
      } else {
        completer.complete([]);
      }
    });

    return completer.future;
  }

  /// Get latitude/longitude from a Place ID
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

  /// Get host browser location using HTML Geolocation API
  ///
  /// Returns a map: {"lat": latitude, "lng": longitude}
  /// If denied, fallback to default coordinates (Kuala Lumpur)
  Future<Map<String, double>> getHostLocation() async {
    final completer = Completer<Map<String, double>>();

    if (window.navigator.geolocation != null) {
      window.navigator.geolocation!.getCurrentPosition().then((position) {
        final lat = position.coords.latitude;
        final lng = position.coords.longitude;
        completer.complete({"lat": lat, "lng": lng});
      }).catchError((error) {
        print("Location permission denied or error: $error");
        completer.complete({"lat": 3.1390, "lng": 101.6869});
      });
    } else {
      completer.complete({"lat": 3.1390, "lng": 101.6869});
    }

    return completer.future;
  }
}
