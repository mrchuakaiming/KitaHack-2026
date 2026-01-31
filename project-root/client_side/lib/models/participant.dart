/// ParticipantModel
///
/// Represents a user's participation in a room.
///
/// Responsibilities:
/// - Store per-room user data (uid + roomId as composite key)
/// - Hold live preferences (submitted for this room, ≤ 3)
/// - Hold default preferences (from user profile, cuisine only, unlimited)
/// - Store budget range as a tuple (min, max)
/// - Store dietary restrictions
/// - Support Firestore serialization / deserialization
///
/// Important:
/// - ONLY `livePreferences`, `budget`, and `dietaryRestrictions`
///   are sent for AI analysis
/// - `defaultPreferences` are used ONLY for UI pre-selection
class ParticipantModel {
  /// Firebase user ID
  final String uid;

  /// Room ID
  final String roomId;

  /// Live preferences for this room (max 3)
  ///
  /// Each item:
  /// {
  ///   "cuisine": "<string>",
  ///   "placeId": "<google_place_id>"
  /// }
  final List<Map<String, String>> livePreferences;

  /// Default preferences from user profile (cuisine only)
  final List<String> defaultPreferences;

  /// Budget range as tuple (min, max)
  ///
  /// Example: (min: 10, max: 40)
  final (int min, int max) budget;

  /// Dietary restrictions
  /// Example: ["halal", "vegetarian"]
  final List<String> dietaryRestrictions;

  ParticipantModel({
    required this.uid,
    required this.roomId,
    List<Map<String, String>>? livePreferences,
    List<String>? defaultPreferences,
    required (int min, int max) budget,
    List<String>? dietaryRestrictions,
  })  : livePreferences =
            (livePreferences != null && livePreferences.length <= 3)
                ? livePreferences
                : [],
        defaultPreferences = defaultPreferences ?? [],
        dietaryRestrictions = dietaryRestrictions ?? [],
        budget = budget;

  /// Convert ParticipantModel → Firestore JSON
  Map<String, dynamic> toJson() => {
        "uid": uid,
        "roomId": roomId,
        "livePreferences": livePreferences,
        "defaultPreferences": defaultPreferences,
        "budget": {
          "min": budget.min,
          "max": budget.max,
        },
        "dietaryRestrictions": dietaryRestrictions,
      };

  /// Create ParticipantModel from Firestore JSON
  factory ParticipantModel.fromJson(Map<String, dynamic> json) {
    final budgetJson = json["budget"] ?? {};

    return ParticipantModel(
      uid: json["uid"],
      roomId: json["roomId"],
      livePreferences: (json["livePreferences"] as List<dynamic>?)
              ?.map((e) => Map<String, String>.from(e))
              .toList() ??
          [],
      defaultPreferences: (json["defaultPreferences"] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      budget: (
        min: budgetJson["min"] ?? 0,
        max: budgetJson["max"] ?? 0,
      ),
      dietaryRestrictions: (json["dietaryRestrictions"] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  /// Add a live preference (≤ 3)
  void addLivePreference(String cuisine, String placeId) {
    if (livePreferences.length >= 3) return;

    livePreferences.add({
      "cuisine": cuisine,
      "placeId": placeId,
    });
  }

  /// Clear live preferences (e.g. when leaving room UI)
  void clearLivePreferences() {
    livePreferences.clear();
  }
}