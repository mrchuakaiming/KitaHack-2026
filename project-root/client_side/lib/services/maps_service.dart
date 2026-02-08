import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';

/// ===============================================================
/// MapsServiceException
/// ===============================================================
///
/// Typed exception thrown by MapsService.
/// UI / ViewModels are expected to catch this and decide how to react
/// (show error, retry, fallback, etc.)
///
class MapsServiceException implements Exception {
  final String message;
  final int? statusCode;

  MapsServiceException(this.message, {this.statusCode});

  @override
  String toString() =>
      "MapsServiceException(message: $message, statusCode: $statusCode)";
}

/// ===============================================================
/// MapsService (Client-Side)
/// ===============================================================
///
/// PURPOSE
/// -------
/// Single client-side entry point for all map-related logic:
/// - Calls server-side Google Maps endpoints
/// - Manages GoogleMap markers
/// - Exposes a clean API for UI / ViewModels
///
/// SECURITY
/// --------
/// - NO Google Maps API keys are stored or used here
/// - All Google Maps calls are routed through the backend
///
/// ARCHITECTURE
/// ------------
/// UI / ViewModel
///     ↓
/// MapsService (this class)
///     ↓ HTTP
/// FastAPI Server (/maps/*)
///     ↓
/// Google Maps API
///
/// ERROR HANDLING CONTRACT
/// ----------------------
/// - This service NEVER prints or swallows errors
/// - All failures throw [MapsServiceException]
/// - UI / ViewModels MUST catch exceptions
///
/// STATE MANAGEMENT CONTRACT
/// -------------------------
/// - This service mutates [markers]
/// - Callers MUST trigger UI rebuilds
///   (setState / notifyListeners / emit)
///
class MapsService {
  final String serverBaseUrl;

  /// Public marker set consumed directly by GoogleMap widget
  ///
  /// Example:
  /// GoogleMap(markers: mapsService.markers)
  final Set<Marker> markers = {};

  MapsService({String? serverUrl})
      : serverBaseUrl = serverUrl ?? Config.serverBaseUrl;

  // ===============================================================
  // CAMERA
  // ===============================================================

  /// Returns an initial camera position.
  ///
  /// UI usage:
  /// ```dart
  /// GoogleMap(
  ///   initialCameraPosition: mapsService.getInitialCamera(),
  ///   markers: mapsService.markers,
  /// )
  /// ```
  CameraPosition getInitialCamera({
    double lat = 3.1390,
    double lng = 101.6869,
    double zoom = 12,
  }) {
    return CameraPosition(
      target: LatLng(lat, lng),
      zoom: zoom,
    );
  }

  // ===============================================================
  // SEARCH (SERVER-SIDE)
  // ===============================================================

  /// Searches for restaurants / places via server-side Google Maps API.
  ///
  /// SERVER:
  /// POST /maps/search
  ///
  /// SIDE EFFECTS:
  /// - Clears all existing markers
  /// - Adds markers for each result
  ///
  /// THROWS:
  /// - [MapsServiceException] on network / server failure
  ///
  /// UI / VM USAGE:
  /// ```dart
  /// try {
  ///   final results = await mapsService.searchRestaurants("ramen");
  ///   setState(() {});
  /// } on MapsServiceException catch (e) {
  ///   showError(e.message);
  /// }
  /// ```
  ///
  /// RETURNS:
  /// List<Map> with:
  /// {
  ///   "name": String,
  ///   "placeId": String,
  ///   "lat": double,
  ///   "lng": double
  /// }
  Future<List<Map<String, dynamic>>> searchRestaurants(String query) async {
    if (query.trim().isEmpty) {
      throw MapsServiceException("Search query cannot be empty");
    }

    final url = Uri.parse("$serverBaseUrl/maps/search");

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"query": query}),
    );

    if (response.statusCode != 200) {
      throw MapsServiceException(
        "Failed to search places",
        statusCode: response.statusCode,
      );
    }

    final data = jsonDecode(response.body) as List<dynamic>;

    _clearMarkers();

    return data.map<Map<String, dynamic>>((e) {
      final lat = e["lat"];
      final lng = e["lng"];
      final name = e["name"] ?? "";
      final placeId = e["placeId"];

      _addMarker(
        markerId: placeId,
        position: LatLng(lat, lng),
        title: name,
      );

      return {
        "name": name,
        "placeId": placeId,
        "lat": lat,
        "lng": lng,
      };
    }).toList();
  }

  // ===============================================================
  // AI RECOMMENDATION
  // ===============================================================

  /// Displays a single marker for an AI-recommended place.
  ///
  /// SERVER:
  /// GET /maps/place/{placeId}
  ///
  /// SIDE EFFECTS:
  /// - Clears existing markers
  /// - Adds exactly ONE marker
  ///
  /// THROWS:
  /// - [MapsServiceException] if place lookup fails
  ///
  /// UI / VM USAGE:
  /// ```dart
  /// try {
  ///   await mapsService.showAIRecommendation(
  ///     recommendedPlaceId: aiResult["recommended_place_id"],
  ///   );
  ///   setState(() {});
  /// } on MapsServiceException catch (e) {
  ///   showError(e.message);
  /// }
  /// ```
  Future<void> showAIRecommendation({
    required String recommendedPlaceId,
    String placeNameFallback = "AI Recommendation",
  }) async {
    _clearMarkers();

    final details = await getPlaceDetails(recommendedPlaceId);

    _addMarker(
      markerId: recommendedPlaceId,
      position: LatLng(details["lat"], details["lng"]),
      title: details["name"] ?? placeNameFallback,
    );
  }

  // ===============================================================
  // PLACE DETAILS (SERVER-SIDE)
  // ===============================================================

  /// Fetches place details from the server.
  ///
  /// SERVER:
  /// GET /maps/place/{placeId}
  ///
  /// THROWS:
  /// - [MapsServiceException] if request fails or place is missing
  ///
  /// RETURNS:
  /// {
  ///   "placeId": String,
  ///   "name": String,
  ///   "lat": double,
  ///   "lng": double
  /// }
  Future<Map<String, dynamic>> getPlaceDetails(String placeId) async {
    final url = Uri.parse("$serverBaseUrl/maps/place/$placeId");

    final response = await http.get(url);

    if (response.statusCode == 404) {
      throw MapsServiceException("Place not found", statusCode: 404);
    }

    if (response.statusCode != 200) {
      throw MapsServiceException(
        "Failed to fetch place details",
        statusCode: response.statusCode,
      );
    }

    final data = jsonDecode(response.body);

    return {
      "placeId": placeId,
      "name": data["name"],
      "lat": data["lat"],
      "lng": data["lng"],
    };
  }

  // ===============================================================
  // MARKER MANAGEMENT (INTERNAL)
  // ===============================================================

  void _addMarker({
    required String markerId,
    required LatLng position,
    required String title,
  }) {
    markers.add(
      Marker(
        markerId: MarkerId(markerId),
        position: position,
        infoWindow: InfoWindow(title: title),
        onTap: () => _launchExternalMap(
          position.latitude,
          position.longitude,
        ),
      ),
    );
  }

  void _clearMarkers() {
    markers.clear();
  }

  // ===============================================================
  // EXTERNAL MAP LAUNCH
  // ===============================================================

  void _launchExternalMap(double lat, double lng) async {
    final uri = Uri.parse(
      "https://www.google.com/maps/search/?api=1&query=$lat,$lng",
    );

    if (!await canLaunchUrl(uri)) {
      throw MapsServiceException("Unable to open external map");
    }

    await launchUrl(uri);
  }
}
