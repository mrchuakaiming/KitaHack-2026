// EXAMPLE USAGE
/*
// From Firestore
final userDoc = await firestore.doc('users/$uid').get();
final user = UserModel.fromJson(userDoc.data()!, userDoc.id);

// Modify locally
final updatedUser = user.copyWith(
  dietaryRestrictions: [...user.dietaryRestrictions, 'halal'],
);

// Save back to Firestore
await firestore.doc('users/$uid').set(updatedUser.toJson());
*/

/*
NOTE: In firestore_service.dart, the serialisation/deserialisation is done by 
the object of the class, not some separate logic we write in firestore_service.
*/

/// UserModel represents a user document stored in Firestore.
/// This is application-level user data, NOT Firebase Auth internals.
class UserModel {
  /// Firebase Auth user ID (used as Firestore document ID)
  final String uid;

  /// Display username chosen by the user
  final String username;

  /// Email address (duplicated from Firebase Auth for convenience)
  final String email;

  /// List of dietary restrictions (e.g. ["vegan", "halal"])
  final List<String> dietaryRestrictions;

  /// List of preferred cuisines (e.g. ["italian", "japanese"])
  final List<String> preferredCuisine;

  /// IDs of rooms hosted by this user
  /// NOTE: This data is NOT stored in Firestore and is injected separately,
  /// similar to how `uid` is supplied outside of Firestore JSON.
  final List<String> hostedRooms;

  /// Main constructor
  /// Dart style: explicit, typed, immutable fields
  UserModel({
    required this.uid,
    required this.username,
    required this.email,
    required this.dietaryRestrictions,
    required this.preferredCuisine,
    required this.hostedRooms,
  });

  /* --------------------------------------------------------------------------
   * Serialization / Deserialization
   * -------------------------------------------------------------------------- */

  /// Create a UserModel from Firestore JSON data
  /// Equivalent to Python: User(**dict)
  ///
  /// NOTE:
  /// - `uid` is supplied externally (Firestore document ID)
  /// - `hostedRooms` is supplied externally (derived data)
  factory UserModel.fromJson(
    Map<String, dynamic> json,
    String uid, {
    List<String> hostedRooms = const [],
  }) {
    return UserModel(
      uid: uid,
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      dietaryRestrictions:
          List<String>.from(json['dietary_restrictions'] ?? []),
      preferredCuisine:
          List<String>.from(json['preferred_cuisine'] ?? []),
      hostedRooms: hostedRooms,
    );
  }

  /// Convert UserModel into JSON for Firestore
  /// Equivalent to Python: dataclass -> dict
  ///
  /// NOTE: `uid` and `hostedRooms` are intentionally omitted.
  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'email': email,
      'dietary_restrictions': dietaryRestrictions,
      'preferred_cuisine': preferredCuisine,
    };
  }

  /* --------------------------------------------------------------------------
   * Utility helpers
   * -------------------------------------------------------------------------- */

  /// Create a modified copy of the user.
  /// Common Dart pattern for immutability.
  UserModel copyWith({
    String? username,
    String? email,
    List<String>? dietaryRestrictions,
    List<String>? preferredCuisine,
    List<String>? hostedRooms,
  }) {
    return UserModel(
      uid: uid,
      username: username ?? this.username,
      email: email ?? this.email,
      dietaryRestrictions:
          dietaryRestrictions ?? this.dietaryRestrictions,
      preferredCuisine:
          preferredCuisine ?? this.preferredCuisine,
      hostedRooms: hostedRooms ?? this.hostedRooms,
    );
  }
}
