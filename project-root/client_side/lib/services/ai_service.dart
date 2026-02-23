// CHANGED
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/preferences.dart';

/// AIService
///
/// Client-side transport layer.
/// Sends aggregated participant preferences to the server.
/// Server runs the AI model and returns recommendation + justification.
class AIService {
  final String serverBaseUrl;

  AIService({String? serverUrl}) : serverBaseUrl = serverUrl ?? Config.serverBaseUrl;

  /// Sends aggregated participant preferences to the server.
  /// Returns a map of `String` keys and values (recommendation + justification).
  /// If an error occurs, returns a map with keys "status" and "message".
  Future<Map<String, String>> sendPreferencesData({
    required List<PreferencesModel> participants,
  }) async {
    final url = Uri.parse('$serverBaseUrl/ai/participants');

    final payload = {
      "participants": participants.map((p) => p.toJson()).toList(),
    };

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200) {
        return {
          "status": "error",
          "message": "Server error: ${response.statusCode}",
        };
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return {
          "status": "error",
          "message": "Invalid server response",
        };
      }

      // Convert all values to String to simplify client handling
      return decoded.map((k, v) => MapEntry(k, v?.toString() ?? ""));
    } catch (e, st) {
      return {
        "status": "error",
        "message": "Request failed: $e\n$st",
      };
    }
  }
}
