import 'package:firebase_database/firebase_database.dart';

/// RTDBService
///
/// Service layer for Firebase Realtime Database (RTDB).
/// Only handles the participants table.
///
/// ----------------------------
/// DATA STRUCTURE
/// ----------------------------
/// participants
///   └── {room_id}
///        └── {uid}
///             └── submitted: bool
///
/// ----------------------------
/// NOTES
/// ----------------------------
/// - Runs fully on the client (Flutter Web)
/// - Security MUST be enforced via Firebase Realtime Database Rules
/// - No sensitive logic should live here
class RTDBService {
  final DatabaseReference _rootRef;

  RTDBService({FirebaseDatabase? database})
      : _rootRef = (database ?? FirebaseDatabase.instance).ref();

  // ============================
  // Participants
  // ============================

  /// Mark a participant as submitted in a room
  Future<void> setParticipantSubmitted({
    required String roomId,
    required String uid,
    bool submitted = true,
  }) async {
    await _rootRef
        .child('participants')
        .child(roomId)
        .child(uid)
        .set({
      'submitted': submitted,
    });
  }

  /// Get all participants for a room
  Future<Map<String, dynamic>?> getParticipants(String roomId) async {
    final snapshot = await _rootRef.child('participants').child(roomId).get();
    if (!snapshot.exists) return null;
    return Map<String, dynamic>.from(snapshot.value as Map);
  }

  /// Delete all participants for a room
  Future<void> deleteRoomParticipants(String roomId) async {
    await _rootRef.child('participants').child(roomId).remove();
  }

  /// Delete a single participant from a room
  Future<void> deleteParticipant({
    required String roomId,
    required String uid,
  }) async {
    await _rootRef
        .child('participants')
        .child(roomId)
        .child(uid)
        .remove();
  }
}
