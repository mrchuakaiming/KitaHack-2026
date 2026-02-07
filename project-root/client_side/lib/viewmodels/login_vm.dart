import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// [IMPORT] Business Logic & Services
import '../coordinators/coordinator.dart';
import '../services/analytics_service.dart';

/// The ViewModel for the Login Screen.
///
/// This class acts as the **State Holder** and **Logic Bridge** between the [LoginPage]
/// and the backend [Coordinator].
///
/// **Architectural Role:**
/// - **Input:** Receives email/password from the View.
/// - **Processing:** Delegates authentication to [Coordinator].
/// - **Side Effects:** Triggers Analytics events via [AnalyticsService] on success.
/// - **Output:** Exposes `isLoading` and `errorMessage` to the View for reactive rebuilding.
class LoginViewModel extends ChangeNotifier {
  
  // ====================================================================
  // DEPENDENCIES
  // ====================================================================
  
  /// The Coordinator handles the complex sequence of:
  /// 1. Firebase Auth (Sign In)
  /// 2. Firestore (Fetch User Profile)
  /// 3. Data Aggregation (Fetch Hosted Rooms)
  final Coordinator _coordinator;

  // ====================================================================
  // STATE PROPERTIES
  // ====================================================================
  
  /// True while the network request is active.
  /// Used by the View to show a spinner or disable the "Login" button.
  bool _isLoading = false;

  /// Stores user-friendly error messages to be displayed in a SnackBar or Text widget.
  /// Null implies no error has occurred recently.
  String? _errorMessage;

  // ====================================================================
  // CONSTRUCTOR
  // ====================================================================
  
  /// Creates the ViewModel.
  /// Allows dependency injection of [Coordinator] for unit testing.
  LoginViewModel({Coordinator? coordinator}) 
      : _coordinator = coordinator ?? Coordinator();

  // ====================================================================
  // GETTERS
  // ====================================================================
  
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // ====================================================================
  // PUBLIC ACTIONS
  // ====================================================================

  /// Attempts to sign in the user.
  ///
  /// **Flow:**
  /// 1. Sets loading state to `true`.
  /// 2. Calls [Coordinator.logIn] to authenticate and fetch profile.
  /// 3. On **Success**:
  ///    - Sets the Analytics User ID (link data to this user).
  ///    - Logs the 'login' event.
  ///    - Returns `true`.
  /// 4. On **Failure**:
  ///    - Catches [RegisterFailure] (domain errors) or generic exceptions.
  ///    - Maps errors to `_errorMessage`.
  ///    - Returns `false`.
  ///
  /// **Parameters:**
  /// * [email]: User input email.
  /// * [password]: User input password.
  Future<bool> logIn(String email, String password) async {
    _setLoading(true);
    _clearError();

    try {
      // 1. DELEGATE TO COORDINATOR
      // We await the result because we need the User object for Analytics
      // and to ensure the profile exists before entering the app.
      final result = await _coordinator.logIn(
        email: email, 
        password: password
      );

      // 2. ANALYTICS INTEGRATION (Success Path)
      // Now that we have a valid user, we link all future events to their ID.
      await AnalyticsService().setUserId(result.user.uid);
      
      // Log the specific action "login" with the method used.
      await AnalyticsService().logLogin(method: 'email_password');

      // 3. FINALIZE
      _setLoading(false);
      return true;

    } on RegisterFailure catch (e) {
      // 4. HANDLE DOMAIN ERRORS
      // The Coordinator has already mapped Firebase error codes (like 'user-not-found')
      // into the `e.message` field. We can display this directly to the user.
      _errorMessage = e.message;
      _setLoading(false);
      return false;

    } on FirebaseAuthException catch (e) {
      // DEFENSIVE CODING:
      // Although Coordinator catches this, if a raw Firebase error slips through,
      // we handle it here as a fallback.
      _errorMessage = e.message ?? "Authentication failed.";
      _setLoading(false);
      return false;

    } catch (e) {
      // 5. HANDLE UNEXPECTED ERRORS
      // Network issues, parsing errors, etc.
      _errorMessage = "An unexpected error occurred. Please check your connection.";
      debugPrint("LoginVM Error: $e");
      _setLoading(false);
      return false;
    }
  }

  // ====================================================================
  // INTERNAL HELPERS
  // ====================================================================

  /// Updates the `_isLoading` flag and triggers a UI rebuild.
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  /// Resets the error state.
  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}