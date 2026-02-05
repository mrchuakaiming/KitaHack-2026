/// PreferencesModel
/// -----------------------------------------------------------------------------
/// Represents per-room user preferences stored in Firestore.
///
/// DESIGN PRINCIPLES
/// - This model is treated as IMMUTABLE.
/// - All fields are `final`.
/// - Internal collections are OWNED by the model (no shared references).
/// - Any change produces a NEW instance via `copyWith`.
///
/// WHY THIS MATTERS
/// - Prevents accidental mutation bugs
/// - Ensures Flutter rebuilds correctly
/// - Makes state changes explicit and debuggable
///
/// FIRESTORE JSON SHAPE:
/// {
///   "room_id": "<STRING>",
///   "live_preferences": [ { "<key>": <any> }, ... ],
///   "preferred_cuisine": [ "<STRING>", ... ],
///   "budget": [ <INT_MIN>, <INT_MAX> ],
///   "dietary_restrictions": [ "<STRING>", ... ]
/// }
class PreferencesModel {
  /// The room this preferences document belongs to.
  final String room_id;

  /// Live, per-room preferences with flexible value types.
  /// Example item: {"spice_level": 3, "sharing": true}
  final List<Map<String, dynamic>> livePreferences;

  /// Preferred cuisines (e.g., ["japanese", "thai"]).
  final List<String> preferredCuisine;

  /// Budget as a normalized 2-element list: [min, max].
  /// No assumptions are made about ordering beyond normalization.
  final List<int> budget;

  /// Dietary restrictions (e.g., ["halal", "vegan"]).
  final List<String> dietaryRestrictions;

  /// Creates a PreferencesModel.
  ///
  /// All incoming collections are DEFENSIVELY COPIED so that:
  /// - Callers cannot mutate internal state after construction
  /// - Each PreferencesModel instance fully owns its data
  PreferencesModel({
    required this.room_id,
    required List<Map<String, dynamic>> livePreferences,
    required List<String> preferredCuisine,
    required List<int> budget,
    required List<String> dietaryRestrictions,
  })  : livePreferences = livePreferences
            .map((e) => Map<String, dynamic>.from(e))
            .toList(),
        preferredCuisine = List<String>.from(preferredCuisine),
        budget = List<int>.from(budget),
        dietaryRestrictions = List<String>.from(dietaryRestrictions);

  /*-----------------------------------------------------
  * Serialization / Deserialization
  *----------------------------------------------------*/
  /// Creates a PreferencesModel from Firestore JSON.
  ///
  /// This method is intentionally defensive:
  /// - Missing or malformed fields do NOT crash the app
  /// - Data is normalized into a predictable shape
  /// - Budget is always converted into a 2-element list [min, max]
  factory PreferencesModel.fromJson(Map<String, dynamic> json) {
    final room_id = (json['room_id'] ?? '').toString();

    final livePreferences = (json['live_preferences'] as List? ?? [])
        .map<Map<String, dynamic>>((e) =>
            e is Map ? Map<String, dynamic>.from(e as Map) : <String, dynamic>{})
        .toList();

    final preferredCuisine = (json['preferred_cuisine'] as List? ?? [])
        .map((e) => e.toString().trim())
        .where((s) => s.isNotEmpty)
        .toList();

    // Normalize budget into [min, max]; fallback to [0, 0] if malformed.
    List<int> budget = const [0, 0];
    final rawBudget = json['budget'];

    if (rawBudget is List && rawBudget.length >= 2) {
      final a = rawBudget[0];
      final b = rawBudget[1];
      final minV = (a is num) ? a.floor() : int.tryParse(a.toString()) ?? 0;
      final maxV = (b is num) ? b.floor() : int.tryParse(b.toString()) ?? 0;
      budget = minV <= maxV ? [minV, maxV] : [maxV, minV];
    } else if (rawBudget is Map) {
      final a = rawBudget['min'];
      final b = rawBudget['max'];
      final minV = (a is num) ? a.floor() : int.tryParse('${a ?? 0}') ?? 0;
      final maxV = (b is num) ? b.floor() : int.tryParse('${b ?? 0}') ?? 0;
      budget = minV <= maxV ? [minV, maxV] : [maxV, minV];
    }

    final dietaryRestrictions = (json['dietary_restrictions'] as List? ?? [])
        .map((e) => e.toString().trim())
        .where((s) => s.isNotEmpty)
        .toList();

    return PreferencesModel(
      room_id: room_id,
      livePreferences: livePreferences,
      preferredCuisine: preferredCuisine,
      budget: budget,
      dietaryRestrictions: dietaryRestrictions,
    );
  }

  /// Converts the model into a Firestore-ready JSON map.
  ///
  /// Defensive copies are returned so callers cannot mutate internal state.
  Map<String, dynamic> toJson() {
    return {
      'room_id': room_id,
      'live_preferences': livePreferences
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      'preferred_cuisine': List<String>.from(preferredCuisine),
      'budget': List<int>.from(budget),
      'dietary_restrictions': List<String>.from(dietaryRestrictions),
    };
  }

  /// Creates a new PreferencesModel with selected fields replaced.
  ///
  /// IMPORTANT:
  /// - This is the ONLY supported way to "modify" preferences.
  /// - All collections are copied, ensuring NO shared references.
  /// - The original instance remains unchanged.
  PreferencesModel copyWith({
    String? room_id,
    List<Map<String, dynamic>>? livePreferences,
    List<String>? preferredCuisine,
    List<int>? budget,
    List<String>? dietaryRestrictions,
  }) {
    return PreferencesModel(
      room_id: room_id ?? this.room_id,
      livePreferences: livePreferences ?? this.livePreferences,
      preferredCuisine: preferredCuisine ?? this.preferredCuisine,
      budget: budget ?? this.budget,
      dietaryRestrictions:
          dietaryRestrictions ?? this.dietaryRestrictions,
    );
  }
}

/*
  /// Get live preferences ready for AI (only entries with both cuisine & placeId)
  List<Map<String, String>> get aiReadyPreferences => livePreferences
      .where((p) => p["cuisine"] != null && p["placeId"] != null)
      .map((p) => {
            "cuisine": p["cuisine"] as String,
            "placeId": p["placeId"] as String,
          })
      .toList();
*/
