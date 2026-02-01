import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../coordinators/coordinator.dart';
import '../models/user.dart';

/// The ViewModel for the Settings Page.
///
/// **Scope:**
/// This ViewModel is strictly limited to **Account Mutations**:
/// 1.  Updating Profile details.
/// 2.  Resetting Password.
/// 3.  Deleting the Account.
///
/// It delegates all business logic to the [Coordinator].
class SettingsViewModel extends ChangeNotifier {
  
  // --- DEPENDENCIES ---
  final Coordinator _coordinator;

  // --- STATE ---
  bool _isLoading = false;
  String? _errorMessage;

  // --- CONSTRUCTOR ---
  SettingsViewModel({Coordinator? coordinator}) 
      : _coordinator = coordinator ?? Coordinator();

  // --- GETTERS ---
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // ====================================================================
  // 1. UPDATE PROFILE
  // ====================================================================

  /// Updates the user's mutable profile fields (Username, Cuisines, Dietary).
  ///
  /// **Logic:**
  /// 1.  Identifies the current user via `FirebaseAuth`.
  /// 2.  Constructs a temporary [UserModel] with the new input data.
  /// 3.  Delegates the update to [Coordinator.updateProfile].
  ///
  /// **Parameters:**
  /// * [username]: The new display name.
  /// * [cuisines]: The new list of preferred cuisines.
  /// * [dietary]: The new list of dietary restrictions.
  ///
  /// **Returns:**
  /// * `true` if the update was successful.
  Future<bool> updateProfile({
    required String username,
    required List<String> cuisines,
    required List<String> dietary,
  }) async {
    _setLoading(true);
    _clearError();

    // Get current UID immediately from Auth since we don't maintain local state
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _errorMessage = "You must be logged in to update your profile.";
      _setLoading(false);
      return false;
    }

    try {
      // Construct a model wrapper to pass data to the Coordinator.
      // Note: We populate immutable fields (email/hostedRooms) with 
      // dummy/current data as Coordinator.updateProfile() ignores them.
      final updatedModel = UserModel(
        uid: user.uid,
        email: user.email ?? '', 
        username: username,
        preferredCuisine: cuisines,
        dietaryRestrictions: dietary,
        hostedRooms: [], // Ignored by update logic
      );

      // DELEGATION
      await _coordinator.updateProfile(updated: updatedModel);
      
      _setLoading(false);
      return true;

    } catch (e) {
      _errorMessage = "Update failed: ${e.toString()}";
      _setLoading(false);
      return false;
    }
  }

  // ====================================================================
  // 2. RESET PASSWORD
  // ====================================================================

  /// Triggers a password reset email for the currently logged-in user.
  ///
  /// **Logic:**
  /// 1.  Retrieves the email from the current Auth session.
  /// 2.  Delegates to [Coordinator.resetPassword].
  Future<void> resetPassword() async {
    _setLoading(true);
    _clearError();

    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;

    if (email == null || email.isEmpty) {
      _errorMessage = "No email found for this user.";
      _setLoading(false);
      return;
    }

    try {
      // DELEGATION
      await _coordinator.resetPassword(email);
      // Success is silent (no return value expected by UI)

    } catch (e) {
      _errorMessage = "Failed to send reset email: ${e.toString()}";
    } finally {
      _setLoading(false);
    }
  }

  // ====================================================================
  // 3. DELETE ACCOUNT
  // ====================================================================

  /// Permanently deletes the user's account and data.
  ///
  /// **Logic:**
  /// 1.  Delegates the destructive sequence (Firestore delete -> Auth delete)
  ///     to [Coordinator.deleteAccount].
  ///
  /// **Returns:**
  /// * `true` if successful (Signal to UI to navigate to Login).
  /// * `false` if failed (e.g., requires recent login).
  Future<bool> deleteAccount() async {
    _setLoading(true);
    _clearError();
    
    try {
      // DELEGATION
      await _coordinator.deleteAccount();
      
      _setLoading(false);
      return true; 

    } catch (e) {
      // Handles specific errors like 'requires-recent-login' passed from Coordinator
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  // --- INTERNAL HELPERS ---

  /// Updates the `isLoading` state and notifies the UI to rebuild.
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  /// Clears any previous error messages.
  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}