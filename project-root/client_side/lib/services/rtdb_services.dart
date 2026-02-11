import 'package:firebase_database/firebase_database.dart';

/// RTDBServiceException
class RTDBServiceException implements Exception {
  final String message;
  final Object? originalException;

  RTDBServiceException(this.message, [this.originalException]);

  @override
  String toString() => 'RTDBServiceException(message: $message, original: $originalException)';
}

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
///             ├── submitted: bool
///             └── disconnected_at: timestamp (set by onDisconnect)
///
/// ----------------------------
/// NOTES
/// ----------------------------
/// - Runs fully on the client (Flutter Web / mobile)
/// - Security MUST be enforced via Firebase Realtime Database Rules
/// - No sensitive logic should live here
/// - Use `onDisconnect` for auto offline detection
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
    try {
      await _rootRef
          .child('participants')
          .child(roomId)
          .child(uid)
          .update({'submitted': submitted});
    } catch (e) {
      throw RTDBServiceException('Failed to set participant submitted', e);
    }
  }

  /// Get all participants for a room
  Future<Map<String, dynamic>?> getParticipants(String roomId) async {
    try {
      final snapshot = await _rootRef.child('participants').child(roomId).get();
      if (!snapshot.exists) return null;
      return Map<String, dynamic>.from(snapshot.value as Map);
    } catch (e) {
      throw RTDBServiceException('Failed to fetch participants for room $roomId', e);
    }
  }

  /// Delete all participants for a room
  Future<void> deleteRoomParticipants(String roomId) async {
    try {
      await _rootRef.child('participants').child(roomId).remove();
    } catch (e) {
      throw RTDBServiceException('Failed to delete participants for room $roomId', e);
    }
  }

  /// Delete a single participant from a room
  Future<void> deleteParticipant({
    required String roomId,
    required String uid,
  }) async {
    try {
      await _rootRef.child('participants').child(roomId).child(uid).remove();
    } catch (e) {
      throw RTDBServiceException(
          'Failed to delete participant $uid from room $roomId', e);
    }
  }

  // ============================
  // Online / Offline Tracking
  // ============================

  /// Registers onDisconnect hook for a participant
  ///
  /// When the client disconnects (tab closed, lost connection), Firebase
  /// automatically writes the server timestamp to 'disconnected_at'.
  /// The server / Cloud Function can then remove non-host, non-done users.
  Future<void> registerOnDisconnect({
    required String roomId,
    required String uid,
  }) async {
    try {
      final participantRef =
          _rootRef.child('participants').child(roomId).child(uid);

      // Clear any previous disconnect marker
      await participantRef.child('disconnected_at').remove();

      // Set server timestamp on disconnect
      participantRef.child('disconnected_at').onDisconnect().set(ServerValue.timestamp);
    } catch (e) {
      throw RTDBServiceException(
          'Failed to register onDisconnect for participant $uid in room $roomId', e);
    }
  }

/// Clears the 'disconnected_at' field for a participant if it exists
Future<void> clearDisconnectedAt({
    required String roomId,
    required String uid,
  }) async {
    try {
      await _rootRef
          .child('participants')
          .child(roomId)
          .child(uid)
          .child('disconnected_at')
          .remove();
    } catch (e) {
      throw RTDBServiceException(
          'Failed to clear disconnected_at for participant $uid in room $roomId', e);
    }
  }

}
