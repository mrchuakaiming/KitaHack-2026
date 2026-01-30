import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/room_participants.dart';
import '../models/ai_result_model.dart';

/// AIService
///
/// Handles all AI-related operations for the client-side.
/// Provides a single function for the ViewModel to call:
/// - Sending room participants and selected places to the backend
/// - Receiving AI recommendation
/// - Returning AI result and optionally a user-friendly message
class AIService {
  final String serverBaseUrl; //Replace this with server URL, e.g., "https://yourserver.com"

  AIService({required this.serverBaseUrl});

  /// Generate AI recommendation for a room
  ///
  /// [room] - current room participants and their live preferences
  /// [selectedPlaceIds] - list of Google Place IDs to consider
  ///
  /// Returns [AIResultModel] containing the recommendation
  /// and optionally you can generate a user-friendly string for UI
  Future<AIResultModel> generateRecommendation({
    required RoomParticipants room,
    required List<String> selectedPlaceIds,
  }) async {
    //The endpoint that calls your Python server route /ai/generate
    final url = Uri.parse('$serverBaseUrl/ai/generate'); // <-- this calls the server-side

    // Prepare payload to send to server
    //  Keys must match server-side expected JSON fields:
    // "participants" -> server-side expects room_data["participants"]
    // "selected_place_ids" -> server-side expects room_data["selected_place_ids"]
    final payload = {
      "participants": room.participants, // RoomParticipants list maps directly
      "selected_place_ids": selectedPlaceIds,
    };

    try {
      // This is the actual server call
      final response = await http.post(
        url, // server route
        headers: {"Content-Type": "application/json"}, // server expects JSON
        body: jsonEncode(payload), // serialize Dart Map -> JSON string
      );

      // Check for server-side HTTP errors
      if (response.statusCode != 200) {
        return AIResultModel(
          status: "error",
          reasoning: "Server returned status ${response.statusCode}", // optional: display in UI
        );
      }

      // Parse JSON response from server
      final responseJson = jsonDecode(response.body) as Map<String, dynamic>;

      // Converts server response into AIResultModel (Dart-side)
      // This will include keys returned by the Python server:
      // "status", "recommended_place_id", "recommended_cuisine", "reasoning", "user_message"
      return AIResultModel.fromJson(responseJson);
    } catch (e) {
      // Catch network errors / JSON parsing errors
      return AIResultModel(
        status: "error",
        reasoning: "AI request failed: $e", // can be displayed in the UI
      );
    }
  }
}
