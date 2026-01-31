///Need to change
import 'dart:convert';
import 'package:http/http.dart' as http;

/// AIService
///
/// Client-side transport layer only.
/// No AI logic lives here.
class AIService {
  final String serverBaseUrl;

  AIService({required this.serverBaseUrl}); //change to your server URL

  /// Sends room preference data to server
  ///
  /// Server handles:
  /// data_converter() → our_model() → prompt generation
  Future<Map<String, String>> generateRecommendation({
    required String roomId,
    required List<Map<String, dynamic>> participantsPayload,
  }) async {
    final url = Uri.parse('$serverBaseUrl/ai/generate'); // Endpoint URL

    final payload = {
      "roomId": roomId,
      "participants": participantsPayload,
    };

    try {
      final response = await http.post(
        url, // change
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

      // Server guarantees string-only response
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
