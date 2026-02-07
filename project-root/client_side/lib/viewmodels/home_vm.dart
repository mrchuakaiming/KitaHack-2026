import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// [IMPORT] Business Logic & Services
import '../coordinators/coordinator.dart';
import '../models/user.dart';
import '../services/firestore_service.dart';
import '../services/analytics_service.dart';

/// **ViewModel for the Home Dashboard**
///
/// **Architectural Role:**
/// Manages the state and logic for the Home Screen.
///
/// **Responsibilities:**
/// 1.  **Room Management:** Creating rooms, joining rooms, and fetching hosted rooms.
/// 2.  **Analytics:** Logs creation and join events.
/// 3.  **State Management:** Handles loading states, error messaging, and the list of hosted rooms.
class HomeViewModel extends ChangeNotifier {
  
  // ====================================================================
  // DEPENDENCIES
  // ====================================================================
  
  final Coordinator _coordinator;
  final FirestoreService _db;

  // ====================================================================
  // STATE PROPERTIES
  // ====================================================================
  
  /// True while a network operation is in progress.
  bool _isLoading = false;

  /// Holds error messages for UI display.
  String? _errorMessage;

  /// List of room IDs that the current user is hosting.
  List<String> _hostedRooms = [];

  // ====================================================================
  // CONSTRUCTOR
  // ====================================================================
  
  HomeViewModel({Coordinator? coordinator, FirestoreService? db}) 
      : _coordinator = coordinator ?? Coordinator(),
        _db = db ?? FirestoreService();

  // ====================================================================
  // GETTERS
  // ====================================================================
  
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<String> get hostedRooms => List.unmodifiable(_hostedRooms);

  // ====================================================================
  // 1. INIT / FETCH DATA
  // ====================================================================

  /// Fetches the list of rooms hosted by the current user.
  /// Should be called when the Home Screen initializes.
  Future<void> fetchHostedRooms() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // We don't necessarily need to set full page loading for this background fetch,
    // but for simplicity, we can. Or we can just update the list silently.
    // Here we'll do it silently to avoid UI jitter, or you can add a separate _isFetchingRooms flag.
    
    try {
      final ids = await _coordinator.getHostedRoomIds(hostUid: user.uid);
      _hostedRooms = ids;
      notifyListeners();
    } catch (e) {
      // Log error but maybe don't block the whole UI
      debugPrint("Failed to fetch hosted rooms: $e");
    }
  }

  // ====================================================================
  // 2. CREATE ROOM
  // ====================================================================

  /// Orchestrates the creation of a new room session.
  Future<String?> createRoom() async {
    _setLoading(true);
    _clearError();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _errorMessage = "You must be logged in.";
      _setLoading(false);
      return null;
    }

    try {
      // 1. Fetch current User Profile (Required for Host Capacity Check)
      UserModel? currentUserModel = await _db.getUser(user.uid);
      
      if (currentUserModel == null) {
        _errorMessage = "User profile not found. Please relogin.";
        _setLoading(false);
        return null;
      }

      // 2. Delegate Creation to Coordinator
      UserModel updatedUser = await _coordinator.newRoom(currentUser: currentUserModel);

      // Extract the new Room ID
      final newRoomId = updatedUser.hostedRooms.last;

      // 3. Update Local List
      _hostedRooms = updatedUser.hostedRooms;

      // 4. Analytics
      await AnalyticsService().logRoomCreated(roomId: newRoomId);

      _setLoading(false);
      return newRoomId;

    } on StateError catch (e) {
      _setLoading(false);
      if (e.message == 'host-limit-reached') {
        _errorMessage = "You cannot host more than 5 rooms at once.";
      } else {
        _errorMessage = e.message;
      }
      return null;

    } catch (e) {
      _setLoading(false);
      _errorMessage = "Failed to create room. Please check connection.";
      return null;
    }
  }

  // ====================================================================
  // 3. JOIN ROOM
  // ====================================================================

  /// Attempts to join an existing room.
  Future<bool> joinRoom(String roomId) async {
    _setLoading(true);
    _clearError();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _errorMessage = "You must be logged in.";
      _setLoading(false);
      return false;
    }

    try {
      final status = await _coordinator.joinRoom(
        roomId: roomId, 
        uid: user.uid
      );

      await AnalyticsService().logEvent(
        'join_room_success',
        params: {
          'room_id': roomId,
          'role_status': status,
        }
      );

      _setLoading(false);
      return true;

    } on StateError catch (e) {
      _setLoading(false);
      if (e.message == 'invalid-room-id') {
        _errorMessage = "Please enter a valid Room ID.";
      } else if (e.message == 'room-not-found') {
        _errorMessage = "Room not found. Please check the code.";
      } else {
        _errorMessage = e.message;
      }
      return false;

    } catch (e) {
      _setLoading(false);
      _errorMessage = "Failed to join room. Please try again.";
      return false;
    }
  }

  // ====================================================================
  // INTERNAL HELPERS
  // ====================================================================

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}