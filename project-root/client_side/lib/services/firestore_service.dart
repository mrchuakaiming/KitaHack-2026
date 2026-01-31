import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart'; // adjust the relative path to your UserModel

/// FirestoreService centralizes reads/writes for Firestore.
/// - Users: Strongly typed via `UserModel`.
/// - Rooms: Dictionary-first (Map<String, dynamic>), no dedicated model.
class FirestoreService {
  // Singleton pattern (kept from your original)
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /* ----------------------------- USERS ------------------------------ */

  CollectionReference<Map<String, dynamic>> get _usersCol =>
      _db.collection('users');

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _usersCol.doc(uid);

  /// Create or update a user document using `UserModel`.
  /// Uses `merge: true` so you can upsert safely.
  Future<void> setUser(UserModel user) async {
    await _userDoc(user.uid).set(
      user.toJson(),
      SetOptions(merge: true),
    );
  } 

  /// Fetch a user document once and deserialize to `UserModel`.
  /// Returns null if the document doesn't exist.
  Future<UserModel?> getUser(String uid) async {
    final snap = await _userDoc(uid).get();
    if (!snap.exists) return null;

    final data = snap.data();
    if (data == null) return null;

    // Note: `uid` is supplied externally (doc id), consistent with your model.
    return UserModel.fromJson(data, snap.id);
  } 

  /// Real-time stream of a user as `UserModel?`.
  /// Emits null if the document is deleted.
  Stream<UserModel?> userStream(String uid) {
    return _userDoc(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      final data = snap.data();
      if (data == null) return null;
      return UserModel.fromJson(data, snap.id);
    });
  } 

  /// Partial update to arbitrary user fields.
  /// Example: updateUserFields(uid, {'username': 'newName'})
  Future<void> updateUserFields(String uid, Map<String, dynamic> fields) async {
    await _userDoc(uid).update(fields);
  } 

  /// Replace the whole user document with the serialized `UserModel`.
  /// Be cautious: this *overwrites* fields that are not present in `toJson()`.
  Future<void> replaceUser(UserModel user) async {
    await _userDoc(user.uid).set(user.toJson());
  } 

  /// List helpers:
  /// Append items to list fields with arrayUnion (deduplicates on server).
  Future<void> addUserListItems({
    required String uid,
    List<String> dietaryRestrictions = const [],
    List<String> preferredCuisine = const [],
  }) async {
    final update = <String, dynamic>{};
    if (dietaryRestrictions.isNotEmpty) {
      update['dietary_restrictions'] = FieldValue.arrayUnion(dietaryRestrictions);
    }
    if (preferredCuisine.isNotEmpty) {
      update['preferred_cuisine'] = FieldValue.arrayUnion(preferredCuisine);
    }
    if (update.isEmpty) return;
    await _userDoc(uid).update(update);
  } 

  /// Remove items from list fields with arrayRemove.
  Future<void> removeUserListItems({
    required String uid,
    List<String> dietaryRestrictions = const [],
    List<String> preferredCuisine = const [],
  }) async {
    final update = <String, dynamic>{};
    if (dietaryRestrictions.isNotEmpty) {
      update['dietary_restrictions'] = FieldValue.arrayRemove(dietaryRestrictions);
    }
    if (preferredCuisine.isNotEmpty) {
      update['preferred_cuisine'] = FieldValue.arrayRemove(preferredCuisine);
    }
    if (update.isEmpty) return;
    await _userDoc(uid).update(update);
  } 

  /// Transaction example for advanced, consistent updates (optional).
  /// Useful if you need to read-modify-write with invariants.
  Future<void> updateUserInTransaction(
    String uid,
    UserModel Function(UserModel current) transform,
  ) async {
    await _db.runTransaction((tx) async {
      final ref = _userDoc(uid);
      final snap = await tx.get(ref);
      final current = snap.exists && snap.data() != null
          ? UserModel.fromJson(snap.data()!, snap.id)
          : UserModel(
              uid: uid,
              username: '',
              email: '',
              dietaryRestrictions: const [],
              preferredCuisine: const [],
              hostedRooms: const [],
            );
      final updated = transform(current);
      tx.set(ref, updated.toJson(), SetOptions(merge: true));
    });
  } 

  /* ----------------------------- ROOMS ------------------------------ */
  // No RoomModel by design. We use Map<String, dynamic> directly.

  CollectionReference<Map<String, dynamic>> get _roomsCol =>
      _db.collection('rooms');

  DocumentReference<Map<String, dynamic>> _roomDoc(String roomId) =>
      _roomsCol.doc(roomId);

  /// Create a room by pushing a raw map.
  Future<DocumentReference<Map<String, dynamic>>> createRoom(
      Map<String, dynamic> data) async {
    return await _roomsCol.add(data);
  } 

  /// Fetch one room as a dictionary (or null if missing).
  Future<Map<String, dynamic>?> getRoom(String roomId) async {
    final doc = await _roomDoc(roomId).get();
    if (!doc.exists) return null;
    return doc.data();
  } 

  /// Live updates of a single room as a dictionary.
  Stream<Map<String, dynamic>?> roomStream(String roomId) {
    return _roomDoc(roomId).snapshots().map((doc) => doc.data());
  } 

  /// Partial update: supply only the fields you want to change.
  Future<void> updateRoom(String roomId, Map<String, dynamic> data) async {
    await _roomDoc(roomId).update(data);
  } 

  /// Replace the whole room document (be careful—overwrites).
  Future<void> setRoom(String roomId, Map<String, dynamic> data,
      {bool merge = true}) async {
    await _roomDoc(roomId).set(data, SetOptions(merge: merge));
  } 

  /// Delete a room.
  Future<void> deleteRoom(String roomId) async {
    await _roomDoc(roomId).delete();
  } 

  /// Query: All rooms a user belongs to (dictionary list).
  Stream<List<Map<String, dynamic>>> roomsForUser(String uid) {
    return _roomsCol
        .where('members', arrayContains: uid)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((d) => d.data()).toList());
  } 
}
``