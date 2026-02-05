import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/preferences.dart';

/// AIService
///
/// Client-side transport layer only.
/// Sends aggregated participant preferences to the server.
/// The server internally calls our_model() to generate the AI recommendation.
class AIService {
  final String serverBaseUrl;

  /// Construct with the server base URL
  AIService({required this.serverBaseUrl});

  /// Sends aggregated participant preferences to the server
  ///
  /// Accepts a list of [PreferencesModel] and converts to JSON internally.
  /// Server will run our_model() and return recommendation + justification.
  Future<Map<String, String>> sendPreferencesData({
    required List<PreferencesModel> participants,
  }) async {
    final url = Uri.parse('$serverBaseUrl/ai/participants'); // Calls server endpoint only

    // Convert PreferencesModel list to JSON
    final participantsPayload = participants.map((p) => p.toJson()).toList();

    final payload = {
      "participants": participantsPayload,
    };

    try {
      final response = await http.post(
        url,
        headers: const {
          "Content-Type": "application/json",
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200) {
        return {
          "status": "error",
          "message": "Server error ${response.statusCode}",
        };
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;

      // Convert all values to string for consistent UI handling
      return decoded.map((k, v) => MapEntry(k, v.toString()));
    } catch (e) {
      return {
        "status": "error",
        "message": "Request failed: $e",
      };
    }
  }
}
