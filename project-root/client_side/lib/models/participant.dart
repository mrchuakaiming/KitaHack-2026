class ParticipantModel {
  /// Firebase user ID
  final String uid;

  /// Room ID
  final String roomId;

  /// Live preferences for this room (max 3)
  ///
  /// Each item:
  /// {
  ///   "cuisine": "<string> | null",
  ///   "placeId": "<google_place_id> | null"
  /// }
  final List<Map<String, dynamic>> livePreferences;

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
    List<Map<String, dynamic>>? livePreferences,
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

  /*-----------------------------------------------------
  * Serialization / Deserialization
  *----------------------------------------------------*/

  /// Convert ParticipantModel → Firestore JSON
  Map<String, dynamic> toJson() => {
        "uid": uid,
        "roomId": roomId,
        "livePreferences": livePreferences
            .map((pref) => {
                  if (pref["cuisine"] != null) "cuisine": pref["cuisine"],
                  if (pref["placeId"] != null) "placeId": pref["placeId"],
                })
            .toList(),
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
              ?.map((e) => {
                    "cuisine": e["cuisine"],
                    "placeId": e["placeId"],
                  })
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

  /*-----------------------------------------------------
  * Live Preference Management
  *----------------------------------------------------*/

  /// Add a live preference (≤ 3)
  void addLivePreference(String? cuisine, String? placeId) {
    if (livePreferences.length >= 3) return;
    if ((cuisine == null || cuisine.isEmpty) &&
        (placeId == null || placeId.isEmpty)) return;

    livePreferences.add({
      "cuisine": cuisine,
      "placeId": placeId,
    });
  }

  /// Clear live preferences (e.g. when leaving room UI)
  void clearLivePreferences() {
    livePreferences.clear();
  }

  /// Get live preferences ready for AI (only entries with both cuisine & placeId)
  List<Map<String, String>> get aiReadyPreferences => livePreferences
      .where((p) => p["cuisine"] != null && p["placeId"] != null)
      .map((p) => {
            "cuisine": p["cuisine"] as String,
            "placeId": p["placeId"] as String,
          })
      .toList();
}
