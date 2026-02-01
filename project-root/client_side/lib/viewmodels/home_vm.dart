import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../coordinators/coordinator.dart';
import '../models/user.dart';
import '../services/firestore_service.dart';

/// The ViewModel for the Home Dashboard.
///
/// **Scope:**
/// This ViewModel is currently restricted to **Room Creation** only.
///
/// **Responsibilities:**
/// 1.  **State Management:** Tracks loading state and the list of locally created rooms.
/// 2.  **Action:** Implements [newRoom] to create a room via the Coordinator.
class HomeViewModel extends ChangeNotifier {
  
  // --- DEPENDENCIES ---
  final Coordinator _coordinator;
  final FirestoreService _db;

  // --- STATE ---
  
  /// Stores rooms. Since we don't fetch from DB on init (per instructions),
  /// this will only contain rooms created during this session.
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
  // NEW ROOM ONLY
  // ====================================================================

  /// Orchestrates the creation of a new room.
  ///
  /// **Logic:**
  /// 1.  Checks Authentication.
  /// 2.  Fetches current User context.
  /// 3.  Delegates to [Coordinator.newRoom] (Handles ID Gen, Limits, DB Write).
  /// 4.  Updates local [_hostedRooms] with the result.
  ///
  /// **Returns:**
  /// * `null`: Success.
  /// * `String`: Error code ("limit_reached") or message.
  Future<String?> newRoom() async {
    _setLoading(true);
    _clearError();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _setLoading(false);
      return "You must be logged in.";
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
      // Map specific coordinator errors to UI codes
      if (e.message == 'host-limit-reached') {
        return "limit_reached"; 
      }
      return e.message;
    } catch (e) {
      _setLoading(false);
      return "Failed to create room. Please check your connection.";
    }
  }

  // --- INTERNAL HELPERS ---

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}