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
  final String backendBaseUrl;

  AIService({required this.backendBaseUrl});

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
    final url = Uri.parse('$backendBaseUrl/ai/generate'); // your backend endpoint

    // Prepare payload
    final payload = {
      "participants": room.participants,
      "selected_place_ids": selectedPlaceIds,
    };

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200) {
        return AIResultModel(
          status: "error",
          reasoning: "Backend returned status ${response.statusCode}",
        );
      }

      final responseJson = jsonDecode(response.body) as Map<String, dynamic>;

      return AIResultModel.fromJson(responseJson);
    } catch (e) {
      return AIResultModel(
        status: "error",
        reasoning: "AI request failed: $e",
      );
    }
  }
}
