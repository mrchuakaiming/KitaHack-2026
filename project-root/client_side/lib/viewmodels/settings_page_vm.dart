import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// [IMPORT] Business Logic & Services
import '../coordinators/coordinator.dart';
import '../models/user.dart';
import '../services/analytics_service.dart';

/// **ViewModel for Settings & Profile Management**
///
/// **Architectural Scope:**
/// This ViewModel is strictly scoped to **Account Mutations** (Write Operations).
/// It does **not** manage the "Read" state of the user profile (fetching initial data),
/// as that is handled by the View (or a separate UserProvider) to keep this logic
/// focused purely on transactional actions.
///
/// **Responsibilities:**
/// 1.  **Profile Updates:** Modifying username, cuisines, and dietary restrictions.
/// 2.  **Security:** Sending password reset emails.
/// 3.  **Destructive Actions:** Permanently deleting the account.
/// 4.  **Analytics:** Logging key account lifecycle events.
class SettingsViewModel extends ChangeNotifier {
  
  // ====================================================================
  // DEPENDENCIES
  // ====================================================================
  
  /// The Coordinator handles the complex sequence of Firestore/Auth operations.
  final Coordinator _coordinator;

  // ====================================================================
  // STATE PROPERTIES
  // ====================================================================
  
  /// `true` if a network operation (update, delete, email) is in progress.
  bool _isLoading = false;

  /// Holds the latest error message for UI display. `null` if no error.
  String? _errorMessage;

  // ====================================================================
  // CONSTRUCTOR
  // ====================================================================
  
  SettingsViewModel({Coordinator? coordinator}) 
      : _coordinator = coordinator ?? Coordinator();

  // ====================================================================
  // GETTERS
  // ====================================================================
  
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // ====================================================================
  // 1. UPDATE PROFILE
  // ====================================================================

  /// Updates the user's mutable profile fields.
  ///
  /// **Flow:**
  /// 1.  Checks if a user is currently logged in.
  /// 2.  Wraps inputs into a [UserModel].
  /// 3.  Delegates to [Coordinator.updateProfile].
  /// 4.  **Analytics:** Logs 'profile_update' on success.
  ///
  /// **Parameters:**
  /// * [username]: New display name.
  /// * [cuisines]: Updated list of food preferences.
  /// * [dietary]: Updated list of restrictions.
  ///
  /// **Returns:** `true` if successful.
  Future<bool> updateProfile({
    required String username,
    required List<String> cuisines,
    required List<String> dietary,
  }) async {
    _setLoading(true);
    _clearError();

    // Fail-safe: Ensure we have a UID to update
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _errorMessage = "You must be logged in to update your profile.";
      _setLoading(false);
      return false;
    }

    try {
      // Construct the model. 
      // Note: Immutable fields (email/hostedRooms) are ignored by the 
      // Coordinator's update logic, but required by the Model constructor.
      final updatedModel = UserModel(
        uid: user.uid,
        email: user.email ?? '', 
        username: username.trim(),
        preferredCuisine: cuisines,
        dietaryRestrictions: dietary,
        hostedRooms: [], 
      );

      // 1. DELEGATION
      await _coordinator.updateProfile(updated: updatedModel);
      
      // 2. ANALYTICS
      // Track that the user cares enough to customize their profile
      await AnalyticsService().logEvent(
        'profile_update', 
        params: {
          'cuisine_count': cuisines.length,
          'dietary_count': dietary.length,
        }
      );

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

  /// Triggers a password reset email via Firebase Auth.
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
      // 1. DELEGATION
      await _coordinator.resetPassword(email);
      
      // 2. ANALYTICS
      await AnalyticsService().logEvent('password_reset_request', params: {'source': 'settings'});

    } catch (e) {
      _errorMessage = "Failed to send reset email: ${e.toString()}";
    } finally {
      _setLoading(false);
    }
  }

  // ====================================================================
  // 3. DELETE ACCOUNT
  // ====================================================================

  /// Permanently deletes the user's account and all associated data.
  ///
  /// **Flow:**
  /// 1.  Calls [Coordinator.deleteAccount].
  /// 2.  **Analytics:** Logs 'account_deleted' immediately before returning.
  ///
  /// **Returns:**
  /// * `true` if successful (Signal to View to navigate to Login).
  /// * `false` if failed (e.g., requires recent login).
  Future<bool> deleteAccount() async {
    _setLoading(true);
    _clearError();
    
    try {
      // 1. DELEGATION (Destructive Action)
      await _coordinator.deleteAccount();
      
      // 2. ANALYTICS
      // Important for churn analysis
      await AnalyticsService().logEvent('account_deleted');
      
      _setLoading(false);
      return true; 

    } catch (e) {
      // Handles specific errors like 'requires-recent-login'
      _errorMessage = e.toString().replaceAll("Exception: ", "");
      _setLoading(false);
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