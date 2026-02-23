import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// [IMPORT] Services & Business Logic
import '../services/firestore_service.dart';
import '../services/analytics_service.dart';
import '../coordinators/coordinator.dart';

/// ============================================================================
/// HOME VIEW MODEL
/// ============================================================================
/// Manages the state and logic for the Home Dashboard.
/// 
/// **KEY RESPONSIBILITIES:**
/// 1. **Data Fetching:** Retrieves the list of rooms the current user is hosting.
/// 2. **Room Creation (Gatekeeper):** Enforces strict limits (max 5 rooms) and 
///    prevents race conditions during automated room generation.
/// 3. **Room Joining (Gatekeeper):** Validates a 6-character room code locally 
///    before attempting to query the Firestore database, saving bandwidth and preventing errors.
/// ============================================================================
class HomeViewModel extends ChangeNotifier {
  
  // --- Dependencies ---
  final FirestoreService _firestore;
  final Coordinator _coordinator;

  // --- State Properties ---
  
  /// Holds the list of Room IDs that the current user is actively hosting.
  List<String> _hostedRooms = [];
  
  /// Indicates whether a background operation (fetching, creating, or verifying) is in progress.
  bool _isLoading = false;
  
  /// Holds any error messages to be displayed to the user via the UI.
  String? _errorMessage;

  // --- Constructor ---
  /// Injects dependencies. Defaults to creating new instances if none are provided.
  HomeViewModel({
    FirestoreService? firestore,
    Coordinator? coordinator,
  })  : _firestore = firestore ?? FirestoreService(),
        _coordinator = coordinator ?? Coordinator();

  // --- Getters ---
  
  /// Exposes the list of hosted rooms to the UI list builder.
  List<String> get hostedRooms => _hostedRooms;
  
  /// Exposes the loading state to trigger loading spinners and lock buttons in the UI.
  bool get isLoading => _isLoading;
  
  /// Exposes current error messages to the UI for snackbars or dialogs.
  String? get errorMessage => _errorMessage;

  /// Internal helper to safely grab the currently logged-in Firebase user's ID.
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // ===========================================================================
  // ACTION: FETCHING DATA
  // ===========================================================================

  /// **Refreshes the list of rooms hosted by the current user.**
  /// 
  /// Queries Firestore via the Coordinator to find all active rooms where 
  /// `host_uid` matches the current user.
  Future<void> fetchHostedRooms() async {
    if (_uid.isEmpty) return;

    _setLoading(true);
    try {
      final List<String> liveIds = await _coordinator.getHostedRoomIds(hostUid: _uid);
      _hostedRooms = liveIds;
      debugPrint("HomeVM: Loaded ${_hostedRooms.length} rooms.");
    } catch (e) {
      debugPrint("HomeVM Fetch Error: $e");
    } finally {
      _setLoading(false);
    }
  }

  // ===========================================================================
  // ACTION: CREATE ROOM
  // ===========================================================================

  /// **Attempts to create a new dining room session while strictly enforcing capacity limits.**
  /// 
  /// FLOW:
  /// 1. Drops request if currently loading (Ironclad Lock against button spamming).
  /// 2. Checks if the user is already hosting 5 active rooms.
  /// 3. If limit is reached, aborts and sets a specific rejection message.
  /// 4. If under limit, commands the Coordinator to generate a unique ID and create the DB entry.
  /// 5. Refreshes the local `_hostedRooms` list so the UI updates immediately.
  /// 
  /// Returns the newly created `roomId` if successful, or `null` if it fails.
  Future<String?> createRoom() async {
    if (_uid.isEmpty) return null;

    // [FIX] THE IRONCLAD LOCK (Race Condition Prevention)
    // If the user spams the Create button, the async queue will queue up multiple calls.
    // This lock drops all secondary calls instantly if the first one is still processing,
    // guaranteeing the 5-room validation cannot be bypassed.
    if (_isLoading) return null; 

    _setLoading(true);
    _errorMessage = null;

    try {
      // 1. [VALIDATION] Check current room count securely from the DB
      final currentRooms = await _coordinator.getHostedRoomIds(hostUid: _uid);
      
      if (currentRooms.length >= 5) {
        _errorMessage = "Failed to create new room because you reached maximum of 5 rooms at a time. Please wait for the rooms to expire before creating a new room.";
        return null; // Abort the flow immediately
      }

      // 2. Proceed with Creation Protocol
      final currentUser = await _firestore.getUser(_uid);
      if (currentUser == null) throw Exception("User profile not found.");

      // Commands Coordinator to generate unique ID, write to Firestore, and update user profile
      final updatedUser = await _coordinator.newRoom(currentUser: currentUser);

      // 3. Force Refresh the UI list
      await fetchHostedRooms();

      // Ensure the room exists in local state, then return the most recently added ID
      if (_hostedRooms.isNotEmpty) {
        return _hostedRooms.last;
      }
      return null;

    } catch (e) {
      _errorMessage = "Failed to create room: ${e.toString()}";
      return null;
    } finally {
      // Always unlock the state, even if an exception occurs
      _setLoading(false);
    }
  }

  // ===========================================================================
  // ACTION: VALIDATION (JOIN ROOM GATEKEEPER)
  // ===========================================================================

  /// **Validates a Room ID before allowing the user to attempt joining.**
  /// 
  /// This function acts as a strict "Bouncer". It checks the format of the 
  /// code locally first to prevent unnecessary and potentially crashing 
  /// database calls with malformed data.
  /// 
  /// [roomId]: The raw string entered by the user in the Join Room text field.
  /// Returns `true` if the room exists in Firestore, `false` otherwise.
  Future<bool> verifyRoomExists(String roomId) async {
    // 1. Clean the input (remove accidental spaces and standardize to uppercase)
    // This allows users to type " abc 123 " and still cleanly match "ABC123".
    final cleanId = roomId.trim().toUpperCase();

    // 2. LOCAL VALIDATION: Length Check
    // All valid room IDs generated by the Coordinator are exactly 6 characters.
    if (cleanId.length != 6) {
      _errorMessage = "Room ID must be exactly 6 characters.";
      notifyListeners();
      return false; // Fail instantly, saving a database read
    }

    // 3. LOCAL VALIDATION: Format Check
    // Ensure the user didn't type special characters (e.g., "!@#")
    final validCharacters = RegExp(r'^[A-Z0-9]+$');
    if (!validCharacters.hasMatch(cleanId)) {
      _errorMessage = "Room ID contains invalid characters.";
      notifyListeners();
      return false; 
    }

    // Pass local validation -> Lock state and check the actual database.
    _setLoading(true);
    _errorMessage = null;
    notifyListeners();

    try {
      // 4. DATABASE VALIDATION: Verify existence in Firestore
      final room = await _firestore.getRoom(cleanId);
      if (room == null) {
        _errorMessage = "Room not found. Check the code and try again.";
        return false;
      }
      
      // The room exists and is active!
      return true; 
      
    } catch (e) {
      _errorMessage = "Connection error. Please try again.";
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ===========================================================================
  // STATE MANAGEMENT HELPERS
  // ===========================================================================

  /// Modifies the `_isLoading` flag and signals the Provider to rebuild dependent UI.
  /// Used to toggle spinners and lock interactive elements.
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}