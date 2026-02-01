import 'dart:convert';
import 'package:http/http.dart' as http;
import 'participant_model.dart'; // Make sure this path points to your ParticipantModel

/// AIService
///
/// Client-side transport layer only.
/// Sends aggregated participant data to server.
class AIService {
  final String serverBaseUrl;

  AIService({required this.serverBaseUrl}); // Set to your server URL

  /// Sends aggregated participant preferences to the server
  ///
  /// Accepts a list of ParticipantModel and converts to JSON internally.
  Future<Map<String, String>> sendParticipantsData({
    required List<ParticipantModel> participants,
  }) async {
    final url = Uri.parse('$serverBaseUrl/ai/participants'); // Single server endpoint

    // Convert ParticipantModel list to JSON
    final participantsPayload =
        participants.map((p) => p.toJson()).toList();

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

      // Convert all values to string for consistency
      return decoded.map(
        (k, v) => MapEntry(k, v.toString()),
      );
    } catch (e) {
      return {
        "status": "error",
        "message": "Request failed: $e",
      };
    }
  }
}
