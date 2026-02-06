import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../config.dart'; // Make sure Config.serverBaseUrl exists

/// MapsService
///
/// Handles all Google Maps functionality for Flutter (Web / Mobile).
/// This service does NOT contain any API keys. All API calls are handled by the server.
class MapsService {
  final String serverBaseUrl;

  // Markers are now tracked here to build Flutter widgets
  final Set<Marker> markers = {};

  MapsService({String? serverUrl})
      : serverBaseUrl = serverUrl ?? Config.serverBaseUrl;

  /// ----------------------------
  /// INITIAL CAMERA POSITION
  /// ----------------------------
  CameraPosition getInitialCamera({
    double lat = 3.1390,
    double lng = 101.6869,
    double zoom = 12,
  }) {
    return CameraPosition(target: LatLng(lat, lng), zoom: zoom);
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

      return data.map<Map<String, dynamic>>((e) {
        final lat = e["lat"];
        final lng = e["lng"];
        final name = e["name"] ?? "";

        _addMarker(
          markerId: e["placeId"],
          position: LatLng(lat, lng),
          title: name,
        );

        return {
          "name": name,
          "placeId": e["placeId"],
          "lat": lat,
          "lng": lng,
        };
      }).toList();
    } catch (e) {
      print("[ERROR] searchRestaurants failed: $e");
      return [];
    }
  }

  /// ----------------------------
  /// SHOW AI RECOMMENDATION
  /// ----------------------------
  Future<void> showAIRecommendation({
    required String recommendedPlaceId,
    String placeNameFallback = "AI Recommendation",
  }) async {
    _clearMarkers();

    final details = await getPlaceDetails(recommendedPlaceId);
    if (details == null) return;

    final lat = details["lat"];
    final lng = details["lng"];
    final name = details["name"] ?? placeNameFallback;

    _addMarker(
      markerId: recommendedPlaceId,
      position: LatLng(lat, lng),
      title: name,
    );
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
  /// PRIVATE: MARKERS
  /// ----------------------------
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
        onTap: () => _launchUrl(
            "https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}"),
      ),
    );
  }

  void _clearMarkers() {
    markers.clear();
  }

  /// ----------------------------
  /// HELPER: OPEN URL
  /// ----------------------------
  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      print("Could not launch $url");
    }
  }
}
