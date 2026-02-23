// CHANGED
import 'dart:convert';
import 'package:flutter/foundation.dart'; 
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

/// **MapsServiceException**
/// Custom exception for identifying map-specific network or API failures.
class MapsServiceException implements Exception {
  final String message;
  final int? statusCode;

  MapsServiceException(this.message, {this.statusCode});

  @override
  String toString() => "MapsServiceException: $message (Code: $statusCode)";
}

/// **MapsService**
/// ----------------------------------------------------------------------------
/// Handles restaurant searching via the Python Backend Proxy.
///
/// **Why use a Proxy?**
/// 1. **Security**: Your Google Maps API Key stays safe in the backend `.env`.
/// 2. **CORS**: Bypasses browser restrictions on Flutter Web.
/// 3. **Unified**: Works identically on Android, iOS, and Web.
/// ----------------------------------------------------------------------------
class MapsService {
  
  /// Internal marker set for map visualization.
  final Set<Marker> markers = {};

  /// **getInitialCamera**
  /// Standard starting position for the map (Default: Kuala Lumpur).
  CameraPosition getInitialCamera({
    double lat = 3.1390,
    double lng = 101.6869,
    double zoom = 12,
  }) {
    return CameraPosition(target: LatLng(lat, lng), zoom: zoom);
  }

  /// **searchRestaurants**
  /// --------------------------------------------------------------------------
  /// Calls the Python Backend `/search` endpoint to fetch results.
  /// --------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> searchRestaurants(String query) async {
    if (query.trim().isEmpty) return [];

    // [NEW] Use the centralized Config to point to your Python server
    // This resolves to http://10.0.2.2:5001/... on Android or localhost on Web
    final Uri url = Uri.parse("${Config.serverBaseUrl}/search");

    try {
      debugPrint("MapsService: Proxying search for '$query' to ${url.toString()}");
      
      // We send a POST request with the query in the body
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"query": query}),
      );

      if (response.statusCode != 200) {
        debugPrint("MapsService HTTP Error: ${response.statusCode} - ${response.body}");
        throw MapsServiceException("Server Error", statusCode: response.statusCode);
      }

      final data = jsonDecode(response.body);
      final String status = data['status'];

      // Google returns 'OK' when successful
      if (status != 'OK') {
        debugPrint("MapsService API Error: $status");
        if (status == 'ZERO_RESULTS') return [];
        throw MapsServiceException("Google API Status: $status");
      }

      final List results = data['results'];
      _clearMarkers();

      // Parse the results from the Google JSON format
      return results.map<Map<String, dynamic>>((place) {
        final geometry = place['geometry']['location'];
        final lat = (geometry['lat'] as num).toDouble();
        final lng = (geometry['lng'] as num).toDouble();
        final name = place['name'] ?? "Unknown Restaurant";
        final placeId = place['place_id'] ?? "no_id";

        // Update the marker set for the UI
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
          "address": place['formatted_address'] ?? ""
        };
      }).toList();

    } catch (e) {
      debugPrint("MapsService critical failure: $e");
      // Return empty list so the UI doesn't crash, but shows "No results found"
      return [];
    }
  }

  // --- Internal Helpers ---

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
      ),
    );
  }

  void _clearMarkers() {
    markers.clear();
  }
}