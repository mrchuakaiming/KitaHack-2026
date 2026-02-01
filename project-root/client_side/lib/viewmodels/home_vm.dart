import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../coordinators/coordinator.dart';
import '../models/user.dart';
import '../services/firestore_service.dart'; 

// TODO: joinRoom() function from coordinator.dart

/// The ViewModel for the Home Dashboard.
///
/// This class manages the state for the Home screen, specifically:
/// 1. **Fetching Rooms:** Retrieving the list of rooms hosted by the current user.
/// 2. **Creating Rooms:** Delegating the logic to [Coordinator.newRoom].
/// 3. **Joining Rooms:** Validating room codes.
class HomeViewModel extends ChangeNotifier {
  
  // --- DEPENDENCIES ---
  final Coordinator _coordinator;
  final FirestoreService _db; 

  // --- STATE ---
  List<String> _hostedRooms = [];
  bool _isLoading = false;
  String? _errorMessage;

  // --- CONSTRUCTOR ---
  HomeViewModel({Coordinator? coordinator, FirestoreService? db}) 
      : _coordinator = coordinator ?? Coordinator(),
        _db = db ?? FirestoreService();

  // --- GETTERS ---
  List<String> get hostedRooms => List.unmodifiable(_hostedRooms);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // ====================================================================
  // 1. FETCH ROOMS (Initialization)
  // ====================================================================

  /// Fetches the current user's profile to populate the [hostedRooms] list.
  Future<void> fetchRooms() async {
    _setLoading(true);
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _hostedRooms = [];
      _setLoading(false);
      return;
    }

    try {
      UserModel? userModel = await _db.getUser(user.uid);
      
      if (userModel != null) {
        _hostedRooms = userModel.hostedRooms;
      } else {
        _hostedRooms = [];
      }
    } catch (e) {
      debugPrint("Error fetching rooms: $e");
      _hostedRooms = [];
    } finally {
      _setLoading(false);
    }
  }

  // ====================================================================
  // 2. CREATE NEW ROOM
  // ====================================================================

  /// Orchestrates the creation of a new room via the Coordinator.
  Future<String?> newRoom() async {
    _setLoading(true);
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _setLoading(false);
      return "You must be logged in to create a room.";
    }

    try {
      // 1. Get current user model (required for capacity check)
      UserModel? currentUserModel = await _db.getUser(user.uid);
      
      if (currentUserModel == null) {
        _setLoading(false);
        return "User profile not found.";
      }

      // 2. Delegate creation to Coordinator
      UserModel updatedUser = await _coordinator.newRoom(currentUser: currentUserModel);

      // 3. Update local state
      _hostedRooms = updatedUser.hostedRooms;
      
      _setLoading(false);
      return null; // Success

    } on StateError catch (e) {
      _setLoading(false);
      if (e.message == 'host-limit-reached') {
        return "You have reached the limit of 5 active rooms.";
      }
      return e.message;
    } catch (e) {
      _setLoading(false);
      return "Failed to create room. Please check your connection.";
    }
  }

  // ====================================================================
  // 3. JOIN ROOM
  // ====================================================================

  /// Validates a room code before allowing the user to join.
  Future<bool> joinRoom(String code) async {
    if (code.isEmpty) return false;

    _setLoading(true);

    try {
      // FIX: Use getRoom to check for existence (returns null if not found)
      var roomData = await _db.getRoom(code);
      bool exists = roomData != null;
      
      _setLoading(false);
      return exists;
    } catch (e) {
      _setLoading(false);
      return false;
    }
  }

  // --- INTERNAL HELPERS ---
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}