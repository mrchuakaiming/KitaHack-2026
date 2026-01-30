import 'dart:async';
import 'dart:html';
import 'package:google_maps/google_maps.dart' as gmaps;

/// MapsService
///
/// Handles Google Maps functionality for the web app.
///
/// Now works **without relying on host location**.
class MapsService {
  gmaps.GMap? _map;
  gmaps.PlacesService? _placesService;

  /// List of markers for hidden cuisine search
  List<gmaps.Marker> _markers = [];

  /// Marker for AI-recommended place
  gmaps.Marker? _aiMarker;

  /// Initialize Google Map inside the given HTML element.
  ///
  /// Default center: Kuala Lumpur
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
  /// - recommendedPlaceId → show single marker
  /// - recommendedCuisine → search restaurants globally (no host location)
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

    if (recommendedPlaceId != null) {
      // Show single AI marker
      final location = await _getLatLngFromPlaceId(recommendedPlaceId);
      if (location != null) {
        _addMarker(location["lat"], location["lng"], placeName);
        _map!.center = gmaps.LatLng(location["lat"]!, location["lng"]!);
        _map!.zoom = 15;
      }
    } else if (recommendedCuisine != null) {
      // Hidden search without host location
      final searchResults =
          await _textSearchHidden("$recommendedCuisine restaurant");

      // Add all results as markers
      for (var result in searchResults) {
        final locParts = result["location"].split(",");
        final resLat = double.parse(locParts[0]);
        final resLng = double.parse(locParts[1]);
        _addMarker(resLat, resLng, result["name"]);
      }

      // Center map on first result if exists
      if (searchResults.isNotEmpty) {
        final first = searchResults.first;
        final latLng = first["location"].split(",");
        _map!.center = gmaps.LatLng(
          double.parse(latLng[0]),
          double.parse(latLng[1]),
        );
        _map!.zoom = 13;
      }
    }
  }

  /// Add marker to the map
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

  /// Hidden search for cuisine type (global search)
  Future<List<Map<String, String>>> _textSearchHidden(String query) {
    final completer = Completer<List<Map<String, String>>>();

    final request = gmaps.TextSearchRequest()
      ..query = query
      ..type = 'restaurant'; // still only restaurants

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

  /// Get coordinates from a Place ID
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
