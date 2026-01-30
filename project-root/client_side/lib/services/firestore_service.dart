import 'package:cloud_firestore/cloud_firestore.dart';

// NOT FINALIZED, SERIALIZATION AFFECTS THIS PART OF THE PROGRAM

class FirestoreService {
  // Singleton pattern (optional but common)
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  // Firestore instance
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /* --------------------------------------------------------------------------
   * USERS
   * -------------------------------------------------------------------------- */

  /// Create or update a user document.
  /// Called after signup or when user profile changes.
  Future<void> setUser({
    required String uid,
    required Map<String, dynamic> data,
    // Later: replace Map<String, dynamic> with UserModel
  }) async {
    await _db.collection('users').doc(uid).set(
      data,
      SetOptions(merge: true),
    );
  }

  /// Fetch a user document once.
  /// Later: deserialize into UserModel
  Future<Map<String, dynamic>?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return doc.data();
  }

  /// Listen to real-time updates of a user document.
  /// Used for reactive UI (profile, settings, etc.)
  Stream<Map<String, dynamic>?> userStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map(
      (doc) => doc.data(),
    );
  }

  /* --------------------------------------------------------------------------
   * ROOMS
   * -------------------------------------------------------------------------- */

  /// Create a room document.
  /// data should contain room metadata (name, owner, members, etc.)
  Future<DocumentReference> createRoom(Map<String, dynamic> data) async {
    return await _db.collection('rooms').add(data);
  }

  /// Fetch a single room by ID.
  /// Later: deserialize into RoomModel
  Future<Map<String, dynamic>?> getRoom(String roomId) async {
    final doc = await _db.collection('rooms').doc(roomId).get();
    if (!doc.exists) return null;
    return doc.data();
  }

  /// Listen to updates of a room document.
  Stream<Map<String, dynamic>?> roomStream(String roomId) {
    return _db.collection('rooms').doc(roomId).snapshots().map(
      (doc) => doc.data(),
    );
  }

  /// Update room fields (e.g. title, settings, members)
  Future<void> updateRoom(String roomId, Map<String, dynamic> data) async {
    await _db.collection('rooms').doc(roomId).update(data);
  }

  /// Delete a room
  Future<void> deleteRoom(String roomId) async {
    await _db.collection('rooms').doc(roomId).delete();
  }

  /* --------------------------------------------------------------------------
   * COLLECTION QUERIES
   * -------------------------------------------------------------------------- */

  /// Listen to all rooms a user belongs to.
  /// Later: return List<RoomModel>
  Stream<List<Map<String, dynamic>>> roomsForUser(String uid) {
    return _db
        .collection('rooms')
        .where('members', arrayContains: uid)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => doc.data()).toList(),
        );
  }

  /* --------------------------------------------------------------------------
   * FUTURE EXTENSIONS (placeholders)
   * -------------------------------------------------------------------------- */

  // TODO: Add subcollection access (e.g. room/messages)
  // TODO: Add pagination support (limit, startAfterDocument)
  // TODO: Replace Map<String, dynamic> with model classes
  // TODO: Add Firestore security-rule-aligned helpers
}
