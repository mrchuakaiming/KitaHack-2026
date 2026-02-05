import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/analytics_service.dart';
import '../services/maps_service.dart';
import '../services/ai_service.dart';
import '../services/rtdb_services.dart';
import '../models/user.dart'; // Update path as needed
import '../models/preferences.dart';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart'; // FieldValue, Timestamp

/// Coordinates multi-service flows for the UI (MVVM-friendly).
class Coordinator {
  final AuthService _auth;
  final FirestoreService _db;
  final AnalyticsService _analytics; //remove
  final MapsService _maps;
  final RTDBService _rtdb;

  Coordinator({
    AuthService? auth,
    FirestoreService? db,
    AnalyticsService? analytics, // remove
    MapsService? maps,
    RTDBService? rtdb,
  })  : _auth = auth ?? AuthService(),
        _db = db ?? FirestoreService(),
        _analytics = analytics ?? AnalyticsService(),//remove
        _maps = maps ?? MapsService(),
        _rtdb = rtdb ?? RTDBService();

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

/// Which stage of the registration flow failed.
enum RegisterStage { createUser, updateProfile, logIn, unknown }

/// Structured error the UI can catch and branch on.
class RegisterFailure implements Exception {
  final RegisterStage stage;
  final String code;      // e.g., FirebaseAuthException.code or custom
  final String message;   // human-friendly detail (safe for logs/UX)

  RegisterFailure({
    required this.stage,
    required this.code,
    required this.message,
  });

  @override
  String toString() =>
      'RegisterFailure(stage: $stage, code: $code, message: $message)';
}
  // ---------------------------- createUser ----------------------------

  /// Creates a Firebase Auth user and seeds a minimal user document.
  /// - Only `email` is stored (plus blank profile fields); `username` remains '',
  ///   lists remain `[]`. Profile edits are *not* handled here.
  ///
  /// Returns the [UserCredential] on success.
  Future<UserCredential> createUser({
    required String email,
    required String password,
    bool logAnalytics = true,
  }) async {
    // Step 1: Auth sign-up to obtain uid (UserCredential.user!.uid)
    final userCredential = await _auth.signUp(email, password);
    // Auth wrapper uses FirebaseAuth.createUserWithEmailAndPassword. 
    final user = userCredential.user;
    if (user == null) {
      throw StateError('User creation failed: no Firebase user returned.');
    }

    // Step 2: Seed minimal Firestore doc
    final model = UserModel(
      uid: user.uid,
      username: '',
      email: email,
      dietaryRestrictions: const [],
      preferredCuisine: const [],
      hostedRooms: const [], // not stored server-side
    );

    try {
      await _db.setUser(model); // typed upsert with merge semantics. 
    } catch (e) {
      // Compensating action: remove Auth user to avoid dangling account.
      try { await user.delete(); } catch (_) {}
      rethrow;
    }

    if (logAnalytics) {
      try {
        await _analytics.setUserId(user.uid);
        await _analytics.logEvent('sign_up', params: {'method': 'email_password'});
      } catch (_) {/* non-fatal */}
    }

    return userCredential;
  }

  // --------------------------- updateProfile --------------------------

  /// Updates mutable profile fields ONLY: `username`, `dietary_restrictions`,
  /// `preferred_cuisine`. `uid`/`email` are immutable here.
  Future<void> updateProfile({required UserModel updated}) async {
    final fields = <String, dynamic>{
      'username': updated.username.trim(),
      'dietary_restrictions': updated.dietaryRestrictions
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false),
      'preferred_cuisine': updated.preferredCuisine
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false),
    };

    await _db.updateUserFields(updated.uid, fields); // partial update. 
  }

  // ------------------------------ logIn -------------------------------

  /// Logs a user in with email/password and returns [UserCredential].
  Future<UserCredential> logIn({
    required String email,
    required String password,
    bool logAnalytics = true,
  }) async {
    final cred = await _auth.signIn(email, password); // FirebaseAuth.signInWithEmailAndPassword. 
    if (logAnalytics) {
      try {
        final uid = cred.user?.uid;
        if (uid != null) await _analytics.setUserId(uid);
        await _analytics.logLogin(method: 'email_password'); // logs a 'login' event. 
      } catch (_) {/* non-fatal */}
    }
    return cred;
  }

  // --------------------------- registerUser ---------------------------

  /// MASTER: Register a user end-to-end in one call.
  ///
  /// ORDER OF OPERATIONS
  ///  1) createUser(email, password)           -> Auth + minimal user doc
  ///  2) updateProfile(updated: UserModel)     -> Optional profile fields
  ///  3) logIn(email, password)                -> Ensure authenticated
  ///
  /// INPUT
  ///  - email (String, required)
  ///  - password (String, required)
  ///  - username (String?, optional)
  ///  - dietaryRestrictions (List<String>?, optional)
  ///  - preferredCuisine (List<String>?, optional)
  ///
  /// OUTPUT
  ///  - Returns [UserCredential] from the final `logIn(...)` step.
  ///
  /// ERRORS (UI-detectable)
  ///  - Throws [RegisterFailure] with:
  ///      stage: RegisterStage.createUser | updateProfile | logIn | unknown
  ///      code : FirebaseAuthException.code (auth stages), FirebaseException.code
  ///             for Firestore writes, or 'unknown'
  ///      message: human-readable message
  ///  - Common auth codes your UI may branch on:
  ///      * 'email-already-in-use', 'invalid-email', 'weak-password',
  ///        'user-not-found', 'wrong-password', 'user-disabled'
  ///
  /// ANALYTICS
  ///  - Emits: 'register_started' | 'register_create_user_success'
  ///           | 'register_profile_updated' | 'register_login_success'
  ///           | 'register_completed' | 'register_failed'
  Future<UserCredential> registerUser({
    required String email,
    required String password,
    String? username,
    List<String>? dietaryRestrictions,
    List<String>? preferredCuisine,
  }) async {
    await _safeLogEvent('register_started', params: {'method': 'email_password'});

    UserCredential createdCred;
    try {
      // Avoid double-logging inside child methods; we log centrally here.
      createdCred = await createUser(
        email: email,
        password: password,
        logAnalytics: false,
      );
      await _analytics.setUserId(createdCred.user!.uid);
      await _safeLogEvent('register_create_user_success');
    } on FirebaseAuthException catch (e) {
      await _safeLogEvent('register_failed', params: {'stage': 'create_user', 'code': e.code});
      throw RegisterFailure(
        stage: RegisterStage.createUser,
        code: e.code,
        message: e.message ?? 'Failed to create account.',
      );
    } on FirebaseException catch (e) {
      // Firestore seeding error is already compensated (auth deletion) in createUser.
      await _safeLogEvent('register_failed', params: {'stage': 'create_user_firestore', 'code': e.code});
      throw RegisterFailure(
        stage: RegisterStage.createUser,
        code: e.code,
        message: e.message ?? 'Failed to seed user document.',
      );
    } catch (e) {
      await _safeLogEvent('register_failed', params: {'stage': 'create_user_unknown'});
      throw RegisterFailure(
        stage: RegisterStage.createUser,
        code: 'unknown',
        message: e.toString(),
      );
    }

    // Stage 2: Optional profile update if fields are provided
    final hasProfileData = (username != null) ||
        (dietaryRestrictions != null) ||
        (preferredCuisine != null);

    if (hasProfileData) {
      try {
        final updatedModel = UserModel(
          uid: createdCred.user!.uid,
          email: email,
          username: (username ?? '').trim(),
          dietaryRestrictions: (dietaryRestrictions ?? const [])
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(growable: false),
          preferredCuisine: (preferredCuisine ?? const [])
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(growable: false),
          hostedRooms: const [],
        );
        await updateProfile(updated: updatedModel); // Never touches uid/email. 
        await _safeLogEvent('register_profile_updated');
      } on FirebaseException catch (e) {
        await _safeLogEvent('register_failed', params: {'stage': 'update_profile', 'code': e.code});
        throw RegisterFailure(
          stage: RegisterStage.updateProfile,
          code: e.code,
          message: e.message ?? 'Failed to update profile.',
        );
      } catch (e) {
        await _safeLogEvent('register_failed', params: {'stage': 'update_profile_unknown'});
        throw RegisterFailure(
          stage: RegisterStage.updateProfile,
          code: 'unknown',
          message: e.toString(),
        );
      }
    }

    // Stage 3: Ensure logged in (even though many SDKs sign in after signUp,
    // we standardize by invoking logIn for a predictable return type). 
    try {
      final loggedIn = await logIn(
        email: email,
        password: password,
        logAnalytics: false,
      );
      // Centralized analytics for the master flow:
      final uid = loggedIn.user?.uid ?? createdCred.user?.uid;
      if (uid != null) await _analytics.setUserId(uid);
      await _safeLogEvent('register_login_success', params: {'method': 'email_password'});
      await _analytics.logLogin(method: 'email_password'); // 'login' event. 
      await _safeLogEvent('register_completed', params: {'method': 'email_password'});
      return loggedIn;
    } on FirebaseAuthException catch (e) {
      await _safeLogEvent('register_failed', params: {'stage': 'log_in', 'code': e.code});
      throw RegisterFailure(
        stage: RegisterStage.logIn,
        code: e.code,
        message: e.message ?? 'Failed to log in.',
      );
    } catch (e) {
      await _safeLogEvent('register_failed', params: {'stage': 'log_in_unknown'});
      throw RegisterFailure(
        stage: RegisterStage.logIn,
        code: 'unknown',
        message: e.toString(),
      );
    }
  }

  // -------------------------- private helpers ------------------------

  Future<void> _safeLogEvent(String name, {Map<String, dynamic>? params}) async {
    try {
      await _analytics.logEvent(name, params: params); // generic analytics event. 
    } catch (_) {/* non-fatal */}
  }

    // -------------------------- getHostedRoomIds ---------------------------

    /// Returns the list of room document IDs hosted by the given [hostUid].
    ///
    /// QUERY
    ///   rooms where host_uid == hostUid
    ///
    /// RETURNS
    ///   List<String> — each entry is the Firestore document ID (roomId).
    ///
    /// ERRORS
    ///   Surfaces [FirebaseException] on query errors for the UI to handle.
    Future<List<String>> getHostedRoomIds({required String hostUid}) async {
    // Optional analytics breadcrumbs (non-fatal).
    try { await _analytics.logEvent('get_hosted_room_ids_started', params: {'host_uid': hostUid}); } catch (_) {}

    final snapshot = await FirebaseFirestore.instance
        .collection('rooms')
        .where('host_uid', isEqualTo: hostUid)
        .get(); // single query for hosted rooms 

    final ids = snapshot.docs.map((doc) => doc.id).toList(growable: false);

    try {
        await _analytics.logEvent('get_hosted_room_ids_success', params: {
        'host_uid': hostUid,
        'count': ids.length,
        });
    } catch (_) {}

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
    /// No RoomModel is used—data is written as a raw map.
    /// Required fields:
    ///   room_id, host_uid, done_participants, active_participants,
    ///   output, createdTime, expiryTime
    ///
    /// Returns: void
    Future<void> createRoom({
    required String roomId,
    required String hostUid,
    }) async {
    // Server-created timestamp for 'createdTime'.
    final createdTime = FieldValue.serverTimestamp();

    // Set expiry based on client time (now + 6 hours). Firestore TTL
    // policies can target this field if configured in your project.
    final expiryTime = Timestamp.fromDate(
        DateTime.now().toUtc().add(const Duration(hours: 6)),
    );

    final roomData = <String, dynamic>{
        'room_id': roomId,
        'host_uid': hostUid,
        'done_participants': <String>[],
        'active_participants': <String>[],
        'output': <String, dynamic>{},
        'createdTime': createdTime,
        'expiryTime': expiryTime,
    };

    // Use FirestoreService.setRoom(roomId, data, merge:false) to create/replace. 
    await _db.setRoom(roomId, roomData, merge: false);
    // Optional: lightweight analytics breadcrumb (non-fatal). 
    try { await _analytics.logEvent('room_create_doc_success', params: {'room_id': roomId}); } catch (_) {}
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

    /// MASTER: Creates a new room for [currentUser].
    ///
    /// ORDER OF OPERATIONS
    ///  1) Capacity check: user can host at most 5 rooms
    ///  2) Generate roomId via generateRoomId()
    ///  3) Create Firestore room via createRoom(...)
    ///  4) Return an updated UserModel with `hostedRooms += roomId`
    ///
    /// INPUT
    ///  - currentUser (UserModel, required)
    ///
    /// OUTPUT
    ///  - Returns an updated UserModel in which `hostedRooms` contains
    ///    the newly created roomId as the last element.
    ///    (The UI can read `updatedUser.hostedRooms.last` to get the id.)
    ///
    /// ERRORS (UI-detectable)
    ///  - Throws [StateError('host-limit-reached')] if the user already
    ///    hosts 5 rooms.
    ///  - Firestore-related exceptions surface as [FirebaseException]
    ///    from the underlying service calls (create/set). 
    Future<UserModel> newRoom({required UserModel currentUser}) async {
    // 1) Capacity check
    if (currentUser.hostedRooms.length >= 5) {
        // Simple, UI-detectable signal without new helper classes.
        throw StateError('host-limit-reached');
    }

    // Analytics breadcrumb (non-fatal). 
    try { await _analytics.logEvent('room_create_started'); } catch (_) {}

    // 2) Generate a unique roomId
    final roomId = await generateRoomId();

    // 3) Create the room doc
    await createRoom(roomId: roomId, hostUid: currentUser.uid);

    // 4) Update the in-memory model (immutable copy with appended id)
    final updated = currentUser.copyWith(
        hostedRooms: [...currentUser.hostedRooms, roomId],
    );

    // Analytics: log the canonical 'room_created' event. 
    try {
        await _analytics.logRoomCreated(roomId: roomId);
        await _analytics.logEvent('room_created_master', params: {'room_id': roomId});
    } catch (_) {}

    return updated;
    }
}

/* ====================================================================
 * 4. JOIN ROOM
 * --------------------------------------------------------------------
 * This section contains:
 *
 *   - joinRoom(...) : Fetch room data and emit analytics only
 *
 * Design notes:
 *  - This method performs NO validation.
 *  - No capacity checks, no permission checks, no navigation.
 *  - ViewModel is responsible for deciding the user flow.
 *  - Analytics is always fired, even if the room does not exist.
 * ==================================================================== */

  /// Fetches room data from Firestore and logs a join attempt.
  ///
  /// INPUT
  ///  - roomId (String, required)
  ///  - uid    (String, required)
  ///
  /// OUTPUT
  ///  - Returns Map<String, dynamic>? (raw room data or null)
  ///
  /// RESPONSIBILITY
  ///  - Data fetch + analytics ONLY
  ///  - No checks, no side effects
  Future<Map<String, dynamic>?> joinRoom({
    required String roomId,
    required String uid,
  }) async {
    // 1. Fetch room data
    final roomData = await _db.getRoom(roomId);

    // 2. Log analytics (non-fatal)
    try {
      await _analytics.logEvent(
        'join_room_attempt',
        params: {
          'room_id': roomId,
          'user_id': uid,
          'room_exists': roomData != null,
        },
      );
    } catch (_) {/* non-fatal */}

    // 3. Return raw room data
    return roomData;
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
    //Fetch user defaults
    final user = await _db.getUser(uid);

    //Merge live + default preferences (originally from different table)
    final mergedPreferences = PreferencesModel(
      livePreferences: preferences.livePreferences,
      defaultPreferences: user?.preferredCuisine ?? [],
      budget: preferences.budget,
      dietaryRestrictions: user?.dietaryRestrictions ?? [],
    );

    //Store preferences (composite key: room + user)
    await _db.setPreferences(
      roomId: roomId,
      uid: uid,
      data: {
        'room_id': roomId,
        'uid': uid,
        ...mergedPreferences.toJson(),
      },
    );

    //Mark participant as submitted in RTDB
    await _rtdb.setParticipantSubmitted(
      roomId: roomId,
      uid: uid,
      submitted: true,
    );

    return true;
  } catch (e, st) {
    print('[submitPreference] Failed: $e\n$st');
    return false;
  }
}

/* ====================================================================
 * 6. RECOMMENDATION
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
Future<Map<String, dynamic>> generateRecommendation({
  required String roomId,
}) async {
  // Fetch all preferences for the room
  final prefList = await _db.getAllPreferencesForRoom(roomId);

  if (prefList.isEmpty) {
    throw Exception('No preferences submitted for room $roomId');
  }

  // Convert to PreferencesModel list
  final preferences = prefList.map((p) => PreferencesModel.fromJson(p)).toList();

  // Call AI service
  final result = await _ai.generateRecommendation(preferences);
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
 * 8. UPDATE PROFILE
 * --------------------------------------------------------------------
 * This section handles updating mutable user profile fields.
 *
 * Design notes:
 *  - Users can change:
 *      * username
 *      * dietaryRestrictions
 *      * preferredCuisine (default cuisine preferences)
 *  - Email and uid are immutable
 *  - Updates Firestore only via UserModel serialization
 *  - Errors are wrapped in application-level exceptions
 * ==================================================================== */

/// Updates the currently signed-in user's profile in Firestore.
Future<void> updateProfile({required UserModel updated}) async {
  try {
    // Prepare Firestore fields for partial update.
    // Trim whitespace and remove any empty strings to avoid storing invalid data.
    final fields = <String, dynamic>{
      'username': updated.username.trim(), // Updated username
      'dietary_restrictions': updated.dietaryRestrictions
          .map((e) => e.trim())           // Trim each dietary restriction
          .where((e) => e.isNotEmpty)     // Remove empty strings
          .toList(growable: false),       // Immutable list for Firestore
      'preferred_cuisine': updated.preferredCuisine
          .map((e) => e.trim())           // Trim each cuisine
          .where((e) => e.isNotEmpty)     // Remove empty strings
          .toList(growable: false),       // Immutable list for Firestore
    };

    // Perform the partial update in Firestore using a helper service
    await FirestoreService().updateUserFields(updated.uid, fields);
  } on FirebaseException catch (e) {
    // Firebase-specific errors are caught and rethrown with more context
    throw Exception(
      'Failed to update profile (${e.code}): ${e.message}',
    );
  } catch (e) {
    // Catch-all for any unexpected errors
    throw Exception('Unexpected error while updating profile: $e');
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
      await _auth.sendPasswordResetEmail(email.trim());
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
  final user = _auth._auth.currentUser;

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

