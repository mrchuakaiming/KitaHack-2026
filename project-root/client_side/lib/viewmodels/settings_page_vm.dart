import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../coordinators/coordinator.dart';
import '../models/user.dart';
import '../services/firestore_service.dart';

/// The ViewModel for the User Settings / Profile Page.
///
/// This class manages:
/// 1. **Profile Data:** Fetching and displaying the current [UserModel].
/// 2. **Edit Mode:** Toggling the UI between "Read-Only" and "Edit".
/// 3. **Account Actions:** Delegating Clear Data and Delete Account operations to the [Coordinator].
class SettingsViewModel extends ChangeNotifier {
  
  // --- DEPENDENCIES ---
  final Coordinator _coordinator;
  final FirestoreService _db;

  // --- STATE ---
  
  /// The current user's profile data.
  UserModel? _userModel;

  /// Indicates if we are currently fetching data or performing an action.
  bool _isLoading = false;

  /// Controls whether the UI text fields are enabled.
  bool _isEditing = false;

  /// Stores error messages for UI display.
  String? _errorMessage;

  // --- CONSTRUCTOR ---
  SettingsViewModel({Coordinator? coordinator, FirestoreService? db}) 
      : _coordinator = coordinator ?? Coordinator(),
        _db = db ?? FirestoreService();

  // --- GETTERS ---
  UserModel? get userModel => _userModel;
  bool get isLoading => _isLoading;
  bool get isEditing => _isEditing;
  String? get errorMessage => _errorMessage;

  // --- INITIALIZATION ---

  /// Loads the current user's profile from Firestore.
  /// Should be called in `initState`.
  Future<void> loadProfile() async {
    _setLoading(true);
    _errorMessage = null;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _errorMessage = "Not logged in.";
      _setLoading(false);
      return;
    }

    try {
      // Fetch directly from Firestore Service
      _userModel = await _db.getUser(user.uid);
    } catch (e) {
      _errorMessage = "Failed to load profile.";
    } finally {
      _setLoading(false);
    }
  }

  // --- ACTIONS ---

  /// 1. Update Profile
  ///
  /// Saves changes to the username, cuisines, or dietary restrictions.
  /// Delegates to [Coordinator.updateProfile].
  ///
  /// **Returns:**
  /// * `true` if successful.
  Future<bool> updateProfile({
    required String username,
    required List<String> cuisines,
    required List<String> dietary,
  }) async {
    if (_userModel == null) return false;
    _setLoading(true);
    _errorMessage = null;

    try {
      // Create an updated model copy
      final updated = _userModel!.copyWith(
        username: username,
        preferredCuisine: cuisines,
        dietaryRestrictions: dietary,
      );

      // Delegate to Coordinator
      await _coordinator.updateProfile(updated: updated);
      
      // Update local state on success
      _userModel = updated;
      _isEditing = false; // Exit edit mode
      
      _setLoading(false);
      return true;

    } catch (e) {
      _errorMessage = "Update failed: ${e.toString()}";
      _setLoading(false);
      return false;
    }
  }

  /// 2. Clear Data (Reset Preferences)
  ///
  /// Clears the user's history and preferences without deleting the account.
  /// **Logic:** It creates a copy of the user model with empty preference lists
  /// and calls [updateProfile] to save it.
  Future<bool> clearData() async {
    if (_userModel == null) return false;
    _setLoading(true);

    try {
      // Create a "cleared" model
      final clearedModel = _userModel!.copyWith(
        preferredCuisine: [],
        dietaryRestrictions: [],
      );

      // Use Coordinator to persist
      await _coordinator.updateProfile(updated: clearedModel);

      // Update local state
      _userModel = clearedModel;
      
      _setLoading(false);
      return true;

    } catch (e) {
      _errorMessage = "Failed to clear data.";
      _setLoading(false);
      return false;
    }
  }

  /// 3. Delete Account (Remove Account)
  ///
  /// Permanently deletes Firestore data and the Auth account.
  /// Delegates to [Coordinator.deleteAccount].
  ///
  /// **Returns:**
  /// * `true` if successful (signal View to navigate to Login).
  /// * `false` if failed (e.g., requires recent login).
  Future<bool> rmAccount() async {
    _setLoading(true);
    
    try {
      // Coordinator handles the sequence: Delete Firestore -> Delete Auth
      await _coordinator.deleteAccount();
      
      // Clear local state
      _userModel = null;
      
      _setLoading(false);
      return true; 

    } catch (e) {
      _errorMessage = e.toString(); // e.g. "Requires recent login"
      _setLoading(false);
      return false;
    }
  }

  // --- UI HELPERS ---

  /// Toggles the editing state for the Profile section.
  void toggleEdit() {
    _isEditing = !_isEditing;
    // If cancelling edit, notify listeners to revert UI
    notifyListeners(); 
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}