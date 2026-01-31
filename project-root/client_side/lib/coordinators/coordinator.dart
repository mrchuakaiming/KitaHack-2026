import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/analytics_service.dart';
import '../models/user.dart'; // Update path as needed
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart'; // FieldValue, Timestamp

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

/// Coordinates multi-service flows for the UI (MVVM-friendly).
class Coordinator {
  final AuthService _auth;
  final FirestoreService _db;
  final AnalyticsService _analytics;

  Coordinator({
    AuthService? auth,
    FirestoreService? db,
    AnalyticsService? analytics,
  })  : _auth = auth ?? AuthService(),
        _db = db ?? FirestoreService(),
        _analytics = analytics ?? AnalyticsService();

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