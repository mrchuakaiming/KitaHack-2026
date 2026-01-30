/// RoomParticipants
/// 
/// Represents the list of participants in a room for the web app.
/// Each participant contains their email, username, live preferences for the room,
/// and budget for the session. Preferences are structured as a list of maps:
/// {"cuisine": "<type>", "restaurants": ["<place_id1>", "<place_id2>", ...]}.
/// 
/// This class is used on the client-side to:
/// 1. Store the current state of participants in a room.
/// 2. Serialize to JSON when sending updates to the backend.
/// 3. Deserialize from JSON received from the backend.
///
/// Example usage:
/// ```dart
/// final room = RoomParticipants(
///   roomId: "ABC123",
///   participants: [
///     {
///       "email": "alice@example.com",
///       "username": "Alice",
///       "preferences": [
///         {"cuisine": "Italian", "restaurants": ["place1", "place2"]},
///       ],
///       "budget": "medium"
///     }
///   ],
/// );
/// final jsonData = room.toJson(); // send to backend
/// final roomFromBackend = RoomParticipants.fromJson(responseJson);
/// ```
class RoomParticipants {
  final String roomId;                     // Room this participant list belongs to
  final List<Map<String, dynamic>> participants; 
  // Each participant map contains:
  // {
  //   "email": "...",
  //   "username": "...",
  //   "preferences": [{"cuisine": "...", "restaurants": ["place_id1"]}, ...],
  //   "budget": "medium"
  // }

  RoomParticipants({
    required this.roomId,
    required this.participants,
  });

  /// Convert Dart object → JSON
  Map<String, dynamic> toJson() => {
        "room_id": roomId,
        "participants": participants,
      };

  /// Create from server side JSON
  factory RoomParticipants.fromJson(Map<String, dynamic> json) {
    return RoomParticipants(
      roomId: json["room_id"],
      participants: List<Map<String, dynamic>>.from(json["participants"] ?? []), //Default to empty list if sends nothing
    );
  }
}
