/// AIResultModel
///
/// Represents the result of AI analysis for a room in the web app.
/// 
/// Fields:
/// - `status`: "success" or "error", indicates if AI successfully produced a result.
/// - `recommendedPlaceId`: the Google Place ID of the recommended restaurant (nullable).
/// - `recommendedCuisine`: the recommended cuisine type (nullable).
/// - `reasoning`: a human-readable explanation of why this recommendation was chosen.
/// - `budget`: optional, if the recommendation considers participants' budgets.
///
/// This class is used on the client-side to:
/// 1. Store the AI-generated recommendation for display in the UI.
/// 2. Serialize to JSON if needed for storage or sending to backend.
/// 3. Deserialize from JSON received from the backend after AI analysis.
///
/// Example usage:
/// ```dart
/// final aiResult = AIResultModel(
///   status: "success",
///   recommendedPlaceId: "place123",
///   recommendedCuisine: "Italian",
///   reasoning: "Most participants preferred Italian cuisine and this place has good ratings.",
///   budget: "medium"
/// );
/// final jsonData = aiResult.toJson(); // send or store
/// final aiResultFromBackend = AIResultModel.fromJson(responseJson);
/// ```
class AIResultModel {
  final String status;               // "success" or "error"
  final String? recommendedPlaceId;  // Google Place ID of recommended restaurant
  final String? recommendedCuisine;  // Recommended cuisine type
  final String reasoning;            // Explanation of recommendation
  final String? budget;              // Optional budget for this recommendation

  AIResultModel({
    required this.status,
    this.recommendedPlaceId,
    this.recommendedCuisine,
    required this.reasoning,
    this.budget,
  });

  /// Convert Dart object → JSON
  Map<String, dynamic> toJson() => {
        "status": status,
        "recommended_place_id": recommendedPlaceId,
        "recommended_cuisine": recommendedCuisine,
        "reasoning": reasoning,
        "budget": budget,
      };

  /// Create from backend JSON
  factory AIResultModel.fromJson(Map<String, dynamic> json) {
    return AIResultModel(
      status: json["status"],
      recommendedPlaceId: json["recommended_place_id"],
      recommendedCuisine: json["recommended_cuisine"],
      reasoning: json["reasoning"] ?? "",
      budget: json["budget"],
    );
  }
}
