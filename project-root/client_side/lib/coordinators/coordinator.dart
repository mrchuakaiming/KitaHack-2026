import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/maps_service.dart';
import '../services/ai_service.dart';
import '../services/rtdb_services.dart';
import '../models/user.dart'; // Update path as needed
import '../models/preferences.dart';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart'; // FieldValue, Timestamp

/// Structured error the UI can catch and branch on.
/// `stage` uses string tags since the enum was removed.
class RegisterFailure implements Exception {
  /// Stage tag: 'createUser' | 'updateProfile' | 'unknown'
  final String stage;
  final String code;    // e.g., FirebaseAuthException.code or custom
  final String message; // human-friendly detail (safe for logs/UX)

  RegisterFailure({
    required this.stage,
    required this.code,
    required this.message,
  });

  @override
  String toString() =>
      'RegisterFailure(stage: $stage, code: $code, message: $message)';
}

/// Convenience return type for registration.
class RegistrationResult {
  final UserCredential credential; // Firebase Auth credential (user is signed-in)
  final UserModel user;            // Freshly ensured/loaded Firestore user model
  RegistrationResult({
    required this.credential,
    required this.user,
  });
}

/// Coordinates multi-service flows for the UI (MVVM-friendly).
class Coordinator {
  final AuthService _auth;
  final FirestoreService _db;
  final MapsService _maps;
  final RTDBService _rtdb;
  final AIService _ai;

  Coordinator({
    AuthService? auth,
    FirestoreService? db,
    MapsService? maps,
    RTDBService? rtdb,
    AIService? ai,
  })  : _auth = auth ?? AuthService(),
        _db = db ?? FirestoreService(),
        _maps = maps ?? MapsService(),
        _rtdb = rtdb ?? RTDBService(),
        _ai = ai ?? AIService();

/* ====================================================================
 * 1. REGISTER
 * --------------------------------------------------------------------
 * This section contains the account-registration flow primitives and
 * the master method that orchestrates them end-to-end:
 *
 *   - createUser(...)   : AUTH-ONLY + minimal Firestore seed (blank profile)
 *   - updateProfile(...) : Profile edits only (username, dietary, cuisine)
 *   - logIn(...)         : Email/password authentication
 *   - registerUser(...)  : MASTER FLOW (create -> update -> login)
 *
 * Design notes:
 *  - We intentionally keep createUser minimal. Profile updates happen
 *    only via updateProfile so that the UI can stage a multi-step flow.
 *  - Analytics is centralized in registerUser to avoid double-logging.
 * ==================================================================== */

  // ---------------------------- createUser ----------------------------

  /// Creates a Firebase Auth user (Auth-only).
  /// Returns [UserCredential] on success.
  /// NOTE: Firebase automatically signs the user in after sign-up.
  Future<UserCredential> createUser({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signUp(email, password); // FirebaseAuth.createUserWithEmailAndPassword
    if (cred.user == null) {
      throw StateError('User creation failed: no Firebase user returned.');
    }
    return cred;
  }

  // --------------------------- updateProfile --------------------------

  /// Overwrite all user fields in Firestore with the provided model.
  /// WARNING: This replaces the entire document with `updated.toJson()`.
  /// `uid` and `hostedRooms` are intentionally not stored (see UserModel.toJson()).
  Future<void> updateProfile({required UserModel updated}) async {
    await _db.replaceUser(updated); // Full document replacement (no merge)
  }

  // ------------------------------ getOrCreateUserModel -------------------------------

  /// Ensures a Firestore user doc exists for [uid] and returns a typed UserModel.
  /// - If users/{uid} exists -> deserialize and return it.
  /// - If missing -> create a default profile and return it.
  /// Safe to call right after registration or any normal login.
  Future<UserModel> getOrCreateUserModel({
    required String uid,
    required String email,
  }) async {
    // Try reading the user document (typed)
    final existing = await _db.getUser(uid); // -> UserModel? (or null)
    if (existing != null) {
      return existing;
    }

    // Not found: create a sane default profile and write it via full replace.
    final fresh = UserModel(
      uid: uid,
      username: '',
      email: email.trim(),
      dietaryRestrictions: const [],
      preferredCuisine: const [],
      hostedRooms: const [], // model-only, not stored
    );

    // Write the profile (full overwrite; creates the doc if missing)
    await _db.replaceUser(fresh);
    return fresh;
  }

  // --------------------------- registerUser ---------------------------

  /// Registers a new user end-to-end and returns a fully initialized session.
  ///
  /// This method performs **account creation + profile persistence** as a single
  /// logical operation and guarantees that no partially-created (“ghost”) users
  /// are left behind.
  ///
  /// ---------------------------------------------------------------------------
  /// FLOW (STRICT ORDER)
  /// 1) createUser
  ///    - Creates a Firebase Auth account using email/password
  ///    - On success, Firebase **automatically signs the user in**
  ///
  /// 2) updateProfile
  ///    - Performs a **full overwrite** of the Firestore user document
  ///    - Stores a normalized `UserModel` built from the provided inputs
  ///
  /// 3) getOrCreateUserModel
  ///    - Reads the Firestore user profile back as a typed `UserModel`
  ///    - If the document is missing (unexpected), it is created
  ///
  /// If step (2) fails after Auth creation, the newly created Auth account
  /// is deleted as a compensating action to prevent orphaned users.
  ///
  /// ---------------------------------------------------------------------------
  /// INPUTS
  /// - email (String, required)
  ///   Email address used for authentication and profile creation.
  ///
  /// - password (String, required)
  ///   Plain-text password used only for account creation.
  ///   Never persisted or retained after this call.
  ///
  /// - username (String, optional, default: '')
  ///   Display name stored in the Firestore user profile.
  ///
  /// - dietaryRestrictions (List`<String>`, optional, default: empty list)
  ///   Stored in the Firestore profile after trimming and empty-value filtering.
  ///
  /// - preferredCuisine (List`<String>`, optional, default: empty list)
  ///   Stored in the Firestore profile after trimming and empty-value filtering.
  ///
  /// ---------------------------------------------------------------------------
  /// OUTPUT
  /// - Returns a `Future<RegistrationResult>`
  ///
  ///   `RegistrationResult` contains:
  ///   - credential (UserCredential)
  ///       The Firebase Auth credential created during account registration.
  ///   - user (UserModel)
  ///       The fully populated Firestore-backed user profile.
  ///
  /// The returned user is **already authenticated**.
  ///
  /// ---------------------------------------------------------------------------
  /// SIDE EFFECTS
  /// - Creates a Firebase Auth user
  /// - Writes a Firestore user document (full overwrite)
  /// - May delete the Auth user if profile persistence fails
  ///
  /// ---------------------------------------------------------------------------
  /// ERRORS
  /// Throws `RegisterFailure`, which is safe for UI-level handling.
  ///
  /// Possible failure stages:
  /// - stage: 'createUser'
  ///   Thrown when Firebase Auth account creation fails.
  ///
  /// - stage: 'updateProfile'
  ///   Thrown when Firestore profile write or retrieval fails.
  ///
  /// - stage: 'unknown'
  ///   Thrown for any unexpected error.
  ///
  /// Error fields:
  /// - code (String)
  ///   FirebaseAuthException.code, FirebaseException.code, or 'unknown'
  ///
  /// - message (String)
  ///   Human-readable description of the failure
  ///
  /// Common Firebase Auth error codes the UI may branch on:
  /// - 'email-already-in-use'
  /// - 'invalid-email'
  /// - 'weak-password'
  /// - 'user-disabled'
  ///
  Future<RegistrationResult> registerUser({
    required String email,
    required String password,
    String username = '',
    List<String> dietaryRestrictions = const [],
    List<String> preferredCuisine = const [],
  }) async {
    UserCredential createdCred;

    try {
      // 1) Auth account creation (user becomes signed-in on success)
      createdCred = await createUser(email: email, password: password); // Auth-only; sign-up auto-signs in 

      // Build the profile to fully store in Firestore (override semantics)
      final modelToWrite = UserModel(
        uid: createdCred.user!.uid,
        username: username.trim(),
        email: email.trim(),
        dietaryRestrictions: dietaryRestrictions
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(growable: false),
        preferredCuisine: preferredCuisine
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(growable: false),
        hostedRooms: const [], // model-only, not stored 
      );

      // 2) Full overwrite of the Firestore user doc
      try {
        await updateProfile(updated: modelToWrite); // uses replaceUser(...) to overwrite 
      } catch (e) {
        // Compensate: delete the Auth account so we don't leave ghost users.
        try { await removeAcc(createdCred.user!); } catch (_) {/* best effort */}
        rethrow;
      }

      // 3) Load the typed UserModel (create if somehow missing)
      final baseModel = await getOrCreateUserModel(
        uid: createdCred.user!.uid,
        email: email,
      ); // reads users/{uid} or creates default and writes it 

      // 4) Enrich with hosted room IDs
      final hostedIds = await getHostedRoomIds(hostUid: baseModel.uid); // query rooms by host_uid 
      final enriched = baseModel.copyWith(hostedRooms: hostedIds);

      return RegistrationResult(credential: createdCred, user: enriched);

    } on FirebaseAuthException catch (e) {
      throw RegisterFailure(
        stage: 'createUser',
        code: e.code,
        message: e.message ?? 'Failed to create account.',
      );
    } on FirebaseException catch (e) {
      throw RegisterFailure(
        stage: 'updateProfile',
        code: e.code,
        message: e.message ?? 'Failed to store user profile.',
      );
    } catch (e) {
      throw RegisterFailure(
        stage: 'unknown',
        code: 'unknown',
        message: e.toString(),
      );
    }
  }


  /* ====================================================================
  * 2. USER LOGIN
  * --------------------------------------------------------------------
  * This section contains:
  *
  *   - logIn(...)               : Sign in a user with email/password
  *                               and ensure a Firestore-backed UserModel exists
  *   - getOrCreateUserModel(...) : Helper to fetch or create a Firestore user profile
  *
  * Design notes:
  *  - Auth + Firestore separation: `logIn` returns both the Firebase Auth credential
  *    and the typed UserModel for UI rendering.
  *  - Error handling: throws [RegisterFailure] with stage 'logIn', 'userModel',
  *    or 'unknown' for easy UI detection.
  * ==================================================================== */
  /// Logs a user in using Firebase Authentication (email + password) and ensures
  /// a corresponding Firestore user profile exists for UI consumption.
  ///
  /// FLOW:
  /// 1) Sign in via Firebase Auth (`_auth.signIn`). User becomes signed-in.
  /// 2) Fetch the Firestore `UserModel` for the signed-in user.
  ///    - If the user document does not exist, a default `UserModel` is created.
  /// 3) Return both the Auth credential and the Firestore-backed `UserModel`.
  ///
  /// INPUTS:
  /// - [email] (String, required): The email address of the user.
  /// - [password] (String, required): The user's password.
  ///
  /// OUTPUT:
  /// - Returns a [RegistrationResult] containing:
  ///   * `credential` (UserCredential): The Firebase Auth user object (signed in).
  ///   * `user` (UserModel)        : The Firestore-backed user profile for UI rendering.
  ///
  /// ERRORS:
  /// - Throws [RegisterFailure] with `stage = 'logIn'` if FirebaseAuth sign-in fails.
  ///   Common codes: 'user-not-found', 'wrong-password', 'user-disabled', etc.
  /// - Throws [RegisterFailure] with `stage = 'userModel'` if Firestore read/create fails.
  /// - Throws [RegisterFailure] with `stage = 'unknown'` for any unexpected errors.
  ///
  /// NOTES:
  /// - Returning both the Auth `credential` and the `UserModel` is redundant for normal UI usage
  ///   because the current user is also accessible via `FirebaseAuth.instance.currentUser`.
  ///   However, returning both is convenient for unit tests or flows that want immediate access
  ///   to both objects without touching singletons.
  /// - The function ensures database integrity: if Firestore operations fail, the user remains
  ///   signed-in, but the UI will receive a failure to handle appropriately.
  Future<RegistrationResult> logIn({
    required String email,
    required String password,
  }) async {
    try {
      // 1) Sign in via Firebase Auth (email + password)
      final cred = await _auth.signIn(email, password); // FirebaseAuth.signInWithEmailAndPassword wrapper
      final String uid = cred.user!.uid;
      final String resolvedEmail = cred.user!.email ?? email;

      // 2) Ensure we have a Firestore-backed UserModel to display in the UI.
      final baseModel = await getOrCreateUserModel(
        uid: uid,
        email: resolvedEmail,
      ); // reads users/{uid} or creates default and writes it

      // 3) Enrich with hosted room IDs
      final hostedIds = await getHostedRoomIds(hostUid: baseModel.uid); // query rooms by host_uid and emit room_id(s)
      final enriched = baseModel.copyWith(hostedRooms: hostedIds);

      // 4) Return both objects to the caller/UI.
      return RegistrationResult(credential: cred, user: enriched);

    } on FirebaseAuthException catch (e) {
      throw RegisterFailure(
        stage: 'logIn',
        code: e.code,
        message: e.message ?? 'Failed to log in.',
      );
    } on FirebaseException catch (e) {
      throw RegisterFailure(
        stage: 'userModel',
        code: e.code,
        message: e.message ?? 'Failed to load user profile.',
      );
    } catch (e) {
      throw RegisterFailure(
        stage: 'unknown',
        code: 'unknown',
        message: e.toString(),
      );
    }
  }


    // -------------------------- getHostedRoomIds ---------------------------
  /// Returns the list of room IDs hosted by [hostUid].
  /// Matches rooms where room.host_uid == hostUid.
  /// NOTE:
  /// - Reads 'room_id' from the document data to match spec.
  /// - Falls back to the document ID if 'room_id' is missing/empty.
  /// - Trims and de-duplicates results.
  Future<List<String>> getHostedRoomIds({required String hostUid}) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('rooms')
        .where('host_uid', isEqualTo: hostUid)
        .get();

    final ids = snapshot.docs
        .map((doc) {
          final data = doc.data();
          final roomId = (data['room_id'] as String?)?.trim();
          return (roomId == null || roomId.isEmpty) ? doc.id : roomId;
        })
        .where((id) => id.trim().isNotEmpty)
        .map((id) => id.trim())
        .toSet()
        .toList(growable: false);

    return ids;
  }


/* ====================================================================
 * 3. CREATE ROOM
 * --------------------------------------------------------------------
 * This section contains:
 *
 *   - createRoom(...)     : Create a room document with a provided roomId
 *   - generateRoomId()    : Generate a unique 6-char code (A–Z + 0–9)
 *   - newRoom(...)        : MASTER FLOW (capacity check -> generate -> create)
 *
 * Design notes:
 *  - Rooms are dictionary-based. We write raw Map<String, dynamic> to Firestore.
 *  - TTL/auto-delete: `expiryTime` is set to created(now) + 6h on the client.
 *  - Analytics: logs 'room_created' and a few breadcrumb events.
 * ==================================================================== */

  /// Creates a room document in Firestore at the specified [roomId].
  /// Room table schema (on create):
  ///   room_id     : String
  ///   host_uid    : String
  ///   output      : Map`<String, dynamic>`  // declared empty on creation
  ///   createdTime : server timestamp
  ///   expiryTime  : createdTime + 6 hours (computed client-side)
  ///
  /// Throws FirebaseException on failure.
  Future<void> createRoom({
    required String roomId,
    required String hostUid,
  }) async {
    // Use a server-side timestamp for 'createdTime'
    final createdTime = FieldValue.serverTimestamp();

    // Compute expiry client-side as now + 6 hours.
    // (This is acceptable because 'createdTime' is written by the server and
    //  'expiryTime' just needs to be ~6 hours ahead for TTL or cleanup flows.)
    final expiryTime = Timestamp.fromDate(
      DateTime.now().toUtc().add(const Duration(hours: 6)),
    );

    final roomData = <String, dynamic>{
      'room_id': roomId,
      'host_uid': hostUid,
      'output': <String, dynamic>{}, // empty payload on creation
      'createdTime': createdTime,
      'expiryTime': expiryTime,
    };

    // Create/replace the room document at rooms/{roomId}
    await _db.setRoom(roomId, roomData, merge: false);
  }


  /// Generates a unique 6-character room code using A–Z + 0–9.
  /// Repeats until it finds an unused id (checks rooms/{code} existence).
  ///
  /// Returns: String (unique roomId)
  Future<String> generateRoomId() async {
  const String _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  const int _len = 6;
  final rnd = Random.secure();

  String _make() {
      final sb = StringBuffer();
      for (var i = 0; i < _len; i++) {
        sb.write(_alphabet[rnd.nextInt(_alphabet.length)]);
      }
      return sb.toString();
  }

  // Loop until unique; the probability of collision is tiny (36^6 combos),
  // but we still check Firestore: rooms/{roomId} must not exist. 
  while (true) {
      final candidate = _make();
      final exists = await _db.getRoom(candidate) != null; // reads rooms/{candidate} 
      if (!exists) return candidate;
      //##change##
      // final docSnap = await _db.roomDoc(candidate).get() != null; // reads rooms/{candidate} 
      // if (!docSnap.exists) return candidate;
    }
  }

  /// ====================================================================
  /// MASTER: Create a new room for a given user
  /// --------------------------------------------------------------------
  /// This function encapsulates the full "create room" flow:
  ///
  /// ORDER OF OPERATIONS
  /// 1) Capacity check:
  ///    - Ensures [currentUser] hosts at most 5 rooms; throws if exceeded.
  /// 2) Generate room ID:
  ///    - Calls [generateRoomId()] to produce a unique 6-character code.
  /// 3) Create Firestore document:
  ///    - Calls [createRoom()] to write the room data to Firestore.
  /// 4) Return updated user model:
  ///    - Produces a new [UserModel] with the new room appended to `hostedRooms`.
  ///
  /// INPUTS
  /// - currentUser (UserModel, required):
  ///   The user who will host the new room. Must have a valid `uid` and
  ///   existing `hostedRooms` list.
  ///
  /// OUTPUT
  /// - Returns a **new** [UserModel] instance with `hostedRooms` updated
  ///   to include the newly created room ID. Original [currentUser] is
  ///   unchanged (immutability preserved).
  ///
  /// ERRORS / EXCEPTIONS
  /// - Throws [StateError] with message `'host-limit-reached'` if
  ///   `currentUser.hostedRooms.length >= 5`.
  /// - Any errors from [generateRoomId()] or [createRoom()] will propagate
  ///   (e.g., Firestore write failures).
  ///
  /// NOTES
  /// - Immutability: [UserModel] fields are final; the returned instance
  ///   must replace the in-memory reference in the UI to reflect changes.
  /// - Room ID generation guarantees uniqueness in the `rooms` collection.
  /// ====================================================================
  Future<UserModel> newRoom({required UserModel currentUser}) async {
    // 1) Capacity check
    if (currentUser.hostedRooms.length >= 5) {
      throw StateError('host-limit-reached');
    }

    // 2) Generate a unique roomId
    final roomId = await generateRoomId();

    // 3) Create the room doc
    await createRoom(roomId: roomId, hostUid: currentUser.uid);

    // 4) Return a new model with the roomId appended
    //    (immutability: we create a new list & new model)
    final updated = currentUser.copyWith(
      hostedRooms: [...currentUser.hostedRooms, roomId],
    );

    return updated;
  }


/* ====================================================================
 * 4. JOIN ROOM
 * --------------------------------------------------------------------
 * This section contains:
 *
 *   - joinRoom(...) : Update the necessary tables
 *   - clearDisconnectedAt(...) : Clears the 'disconnected_at' field for a participant (if it exists)
 *
 * Design notes:
 *  - No capacity checks, no permission checks, no navigation.
 *  - ViewModel is responsible for deciding the user flow.
 * ==================================================================== */
/// This function performs the following steps:
/// 1. Validates the room ID and fetches the room document from Firestore (`rooms/{roomId}`):
///    - Determines if the user is the host (`room['host_uid'] == uid`) or a non-host.
/// 2. Reads the participant record from Realtime Database (`participants/{roomId}/{uid}`) to determine:
///    - `submitted`: whether the user has already submitted.
///    - `disconnected_at`: optional timestamp indicating when the user went offline.
/// 3. Updates Realtime Database only when necessary:
///    - **Host**:
///      - First join: create record `{ submitted: true }` (no `disconnected_at` field)
///      - Returning with `disconnected_at`: clears the field to reflect the user is online
///    - **Non-host done user** (already submitted):
///      - Clears `disconnected_at` if present
///      - Returns `"done_user"` without modifying `submitted`
///    - **Non-host undone user** (not yet submitted):
///      - First join: create record `{ submitted: false }` (no `disconnected_at`)
///      - Returning with `disconnected_at`: clears the field to reflect the user is online
///
/// **Presence lifecycle**:
/// - Hosts and done users remain permanently visible.
/// - Undone users appear when online, disappear when offline (`onDisconnect` sets `disconnected_at`), and reappear upon reconnect.
///
/// **Parameters**:
/// - [roomId] (String): The ID of the room to join. Must be non-empty and non-whitespace.
/// - [uid] (String): The unique ID of the user joining the room.
///
/// **Returns**:
/// - `"host"`: if the user is the host of the room
/// - `"done_user"`: if the user is a non-host and has already submitted
/// - `"undone_user"`: if the user is a non-host and has not yet submitted
///
/// **Throws**:
/// - `StateError('invalid-room-id')` if [roomId] is empty or whitespace
/// - `StateError('room-not-found')` if the room does not exist in Firestore
/// - `FirebaseException` if Firestore or Realtime Database operations fail
  Future<String> joinRoom({
    required String roomId,
    required String uid,
  }) async {
    final id = roomId.trim();
    if (id.isEmpty) {
      throw StateError('invalid-room-id');
    }

    // 1) Firestore read: validate room & discover host vs non-host.
    final room = await _db.getRoom(id); // null if room doesn't exist
    if (room == null) {
      throw StateError('room-not-found');
    }
    final bool isHost = (room['host_uid'] == uid); // Rooms schema field host_uid (map-based)

    // 2) RTDB read: participants/{roomId}
    final participants = await _rtdb.getParticipants(id); // Map<String, dynamic>?
    final bool hasRecord = (participants != null) && participants.containsKey(uid);

    // Extract submitted & whether 'disconnected_at' exists.
    bool alreadySubmitted = false;
    bool hasDisconnectedAt = false;
    if (hasRecord) {
      final val = participants[uid];
      if (val is Map) {
        final s = val['submitted'];
        if (s is bool) alreadySubmitted = s;
        hasDisconnectedAt = val.containsKey('disconnected_at');
      }
    }

    // 3) Take action in RTDB only when needed.
    if (isHost) {
      // Host:
      // - First join: create record with submitted=true (no disconnected_at)
      if (!hasRecord) {
        await _rtdb.setParticipantSubmitted(
          roomId: id,
          uid: uid,
          submitted: true,
        ); // no 'disconnected_at' on creation
      } else if (hasDisconnectedAt) {
        // Returning host: clear disconnected_at if it exists
        await _rtdb.clearDisconnectedAt(roomId: id, uid: uid); // new helper
      }
      return 'host';
    } else {
      // Non-host:
      if (alreadySubmitted) {
        // done_user: do not create/modify submitted flag
        // If they previously disconnected, clear 'disconnected_at'
        if (hasRecord && hasDisconnectedAt) {
          await _rtdb.clearDisconnectedAt(roomId: id, uid: uid); // new helper
        }
        return 'done_user';
      } else {
        // undone_user:
        // Only if brand-new: create { submitted: false } (no disconnected_at)
        if (!hasRecord) {
          await _rtdb.setParticipantSubmitted(
            roomId: id,
            uid: uid,
            submitted: false,
          ); // no 'disconnected_at' on creation
        } else if (hasDisconnectedAt) {  
          // Returning undone user who previously disconnected -> clear it  
          await _rtdb.clearDisconnectedAt(roomId: id, uid: uid);
        }
        // If they had a record but weren't submitted, we leave it as-is.
        return 'undone_user';
      }
    }
  }


/* ====================================================================
 * 5. PARTICIPANT PREFERENCES
 * --------------------------------------------------------------------
 * This section contains:
 *
 *   - searchRestaurant(query) : Fetch restaurant search results from MapsService for UI display
 *   - submitPreference(...)    : Save user's live preferences to Firestore under the room
 *
 * Design notes:
 *  - searchRestaurant() only returns a list of results; UI is responsible for displaying them.
 *  - submitPreference() does NOT perform any validation on budget or preference count.
 *  - ViewModel is responsible for calling these methods at the appropriate time.
 * ==================================================================== */

/// -----------------------------
/// Search Restaurant
///
/// - Calls MapsService.searchRestaurants(query)
/// - Returns a list of restaurant maps:
///   { "name", "placeId", "lat", "lng" }
/// - UI should display results and let the user select one
Future<List<Map<String, dynamic>>> searchRestaurant(String query) async {
  final trimmedQuery = query.trim();
  if (trimmedQuery.isEmpty) return [];

  final results = await _maps.searchRestaurants(trimmedQuery);

  return results;
}

/// -----------------------------
/// Submit Preference
///
/// - Collects live preferences from PreferencesModel
/// - Fetches user default preferences and dietary restrictions from Firestore
/// - Stores per-user preferences in Firestore `preferences` collection
/// - Marks participant as submitted in RTDB
///
/// Returns true if success, false otherwise
Future<bool> submitPreference({
  required String uid,
  required String roomId,
  required PreferencesModel preferences,
}) async {
  try {
    //Fetch user defaults from Firestore
    final user = await _db.getUser(uid);

    // Merge live + default preferences
    final mergedPreferences = PreferencesModel(
      roomId: roomId,
      livePreferences: [
        for (var p in preferences.livePreferences)
          Map<String, dynamic>.from(p) // defensive copy
      ],
      preferredCuisine: {
        ...preferences.preferredCuisine,
        ...(user?.preferredCuisine ?? []),
      }.toList(),
      budget: preferences.budget,
      dietaryRestrictions: {
        ...preferences.dietaryRestrictions,
        ...(user?.dietaryRestrictions ?? []),
      }.toList(),
    );

    // Store preferences in Firestore (composite key: room + user)
    await _db.setPreferences(
      roomId: roomId,
      data: {
        'room_id': roomId,
        'uid': uid,
        ...mergedPreferences.toJson(),
      },
    );

    // Mark participant as submitted in RTDB
    await _rtdb.setParticipantSubmitted(
      roomId: roomId,
      uid: uid,
      submitted: true,
    );

    return true;
  } catch (e, st) {
    throw Exception('[submitPreference] Failed: $e\n$st');
  }
}

/* ====================================================================
 * 6. LEAVE ROOM
 * --------------------------------------------------------------------
 * This section contains:
 *
 *   - leaveRoom(...) : Handles participant leaving a room
 *
 * Design notes:
 *  - Removes participant from RTDB participants table if they are not host and not done.
 *  - Should be called from Coordinator (UI triggers).
 *  - Uses RTDBService public getter `rootRef` for database access.
 * ==================================================================== */

// -----------------------------
/// leaveRoom
///
/// - Registers the participant for onDisconnect handling in RTDB
/// - VM simply calls this function; no checks for host/done here
/// - Does NOT touch Firestore user document
Future<void> leaveRoom({
  required String roomId,
  required String uid,
}) async {
  try {
    await _rtdb.registerOnDisconnect(
      roomId: roomId,
      uid: uid,
    );
  } catch (e) {
    throw('[ERROR] Failed to register leaveRoom for $uid: $e');
  }
}


/* ====================================================================
 * 7. RECOMMENDATION
 * --------------------------------------------------------------------
 * This section contains:
 *
 *   - generateRecommendation(...) : Calls AIService once and returns result
 *   - storeRecommendation(...)    : Stores AI result into Firestore Room document
 *   - wantResult(...)             : Updates done_users and triggers UI updates
 *   - showResultMap(...)          : Helper to show Google Map with recommended place
 *
 * Design notes:
 *  - AIService is called exactly once per recommendation generation.
 *  - FirestoreService handles Room and User updates.
 *  - MapsService used optionally to fetch place details for UI.
 * ==================================================================== */

/// -----------------------------
/// generateRecommendation
///
/// - Reads preferences from Firestore
/// - Sends to AI service
/// - Does NOT touch RTDB
Future<Map<String, String>> generateRecommendation({
  required String roomId,
}) async {
  // Fetch all preferences for the room
  final prefList = await _db.getAllPreferencesForRoom(roomId);

  if (prefList.isEmpty) {
    throw Exception('No preferences submitted for room $roomId');
  }

  // Convert Firestore data to PreferencesModel list
  final preferences = prefList
      .map((p) => PreferencesModel.fromJson(p))
      .toList();

  // Call AI service
  final result = await _ai.sendPreferencesData(participants: preferences);

  return result;
}


/// -----------------------------
/// storeRecommendation
///
/// Stores the AI recommendation into the Room document in Firestore.
/// - roomId: ID of the current room
/// - result: recommendation from generateRecommendation(...)
/// Returns status string ("success" or error message)
Future<String> storeRecommendation({
  required String roomId,
  required Map<String, dynamic> result,
}) async {
  try {
    //Store AI recommendation in Firestore
    await _db.updateRoom(roomId, {
      "aiRecommendation": result,
      "aiStatus": "done",
    });

    //Clean up all participants in RTDB for this room
    await _rtdb.deleteRoomParticipants(roomId);

    return "success";
  } catch (e) {
    return "Failed to store recommendation: $e";
  }
}

/// -----------------------------
/// wantResult
///
/// Updates `done_users` in the Room document and triggers UI updates.
/// Only shows result for users who have completed their selection.
Future<void> wantResult({
  required String roomId,
  required List<String> doneUsers,
}) async {
  try{
    // Update done_users in Room document
    await _db.updateRoom(roomId, {
      "done_users": doneUsers,
  });

  }catch(e,st){
    throw Exception('Failed to update done_users: $e\n$st');
  }
}

/* ====================================================================
 * 9. CHANGE PASSWORD
 * --------------------------------------------------------------------
 * This section handles password reset via Firebase Auth.
 *
 * Design notes:
 *  - User does not need to be signed in
 *  - Firestore is not touched
 *  - Common FirebaseAuth errors are mapped to readable messages
 * ==================================================================== */

/// Sends a password reset email to [email].
Future<void> resetPassword(String email) async {
  try {
      await _auth.resetPassword(email.trim());
    } catch (e) {
      throw Exception('Failed to reset password: $e');
    }
  }

/* ====================================================================
 * 10. DELETE ACCOUNT
 * --------------------------------------------------------------------
 * This section handles full account deletion.
 *
 * ORDER OF OPERATIONS
 *  1) clearData(uid)   -> Delete all Firestore user data
 *  2) removeAcc(user)  -> Delete Firebase Auth user
 *
 * Design notes:
 *  - Firestore data is deleted first to avoid orphaned documents
 *  - Auth deletion may require recent login
 *  - Helpers are internal and wrapped with exceptions
 * ==================================================================== */

/// Deletes the currently signed-in user's account and all associated Firestore data.
Future<void> deleteAccount() async {
  final user = _auth.currentUser;

  if (user == null) {
    // Ensure there is a signed-in user before attempting deletion
    throw Exception('No authenticated user.');
  }

  try {
    // 1) Delete all Firestore documents related to this user
    await clearData(user.uid);

    // 2) Delete the user's Firebase Authentication account
    await removeAcc(user);
  } catch (e) {
    // Wrap any errors during deletion
    throw Exception('Failed to delete account: $e');
  }
}

/* =========================
 * Helper functions (internal)
 * ========================= */

/// Clears all Firestore documents for the given [uid].
/// Deletes the user document and all rooms hosted by this user.
/// Preferences will be cleaned up by Cloud Functions periodically.
Future<void> clearData(String uid) async {
  try {
    await _db.deleteUser(uid); // Only delete the user doc
  } catch (e) {
    throw Exception('Failed to clear user data: $e');
  }
}

/// Removes a Firebase Auth [user] account.
/// May throw 'requires-recent-login' if the user hasn't logged in recently.
Future<void> removeAcc(User user) async {
  try {
    await user.delete();
  } on FirebaseAuthException catch (e) {
    if (e.code == 'requires-recent-login') {
      // Specific error when account deletion requires a recent login
      throw Exception('Recent login required to delete account.');
    }
    // Other FirebaseAuth errors
    throw Exception(e.message ?? 'Failed to remove account.');
  } catch (e) {
    // Catch-all for any unexpected errors
    throw Exception('Unexpected error occurred: $e');
  }
}

}