import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../coordinators/coordinator.dart';

/// The ViewModel for the Login Screen.
///
/// This class acts as the interface between the [LoginPage] UI and the
/// business logic contained in the [Coordinator].
///
/// **Responsibilities:**
/// 1.  **State Management:** exposure of `isLoading` and `errorMessage`.
/// 2.  **Error Translation:** Converts exceptions from the Coordinator into user-friendly strings.
/// 3.  **Action Delegation:** Passes email/password credentials to the Coordinator.
class LoginViewModel extends ChangeNotifier {
  
  // --- DEPENDENCIES ---
  /// The business logic layer. Injected here to allow for future testing/mocking.
  final Coordinator _coordinator;

  // --- STATE ---
  /// Indicates if the authentication process is currently running.
  bool _isLoading = false;

  /// Stores validation or authentication errors to be displayed in the UI.
  String? _errorMessage;

  // --- CONSTRUCTOR ---
  LoginViewModel({Coordinator? coordinator}) 
      : _coordinator = coordinator ?? Coordinator();

  // --- GETTERS ---
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // --- FUNCTIONS ---

  /// Attempts to sign in the user using Email and Password.
  ///
  /// This function calls [Coordinator.logIn].
  ///
  /// **Parameters:**
  /// * [email]: The user's email address.
  /// * [password]: The user's password.
  ///
  /// **Returns:**
  /// * `true`: If login was successful.
  /// * `false`: If login failed (check [errorMessage] for details).
  Future<bool> logIn(String email, String password) async {
    _setLoading(true);
    _clearError();

    try {
      // Delegate to Coordinator for the actual Firebase Auth call & Analytics
      await _coordinator.logIn(
        email: email, 
        password: password
      );
      
      _setLoading(false);
      return true;

    } on FirebaseAuthException catch (e) {
      // Handle specific Firebase Auth errors
      // Note: The Coordinator might throw RegisterFailure or raw Exceptions depending on implementation.
      // We catch FirebaseAuthException here just in case, or map standard codes.
      switch (e.code) {
        case 'user-not-found':
          _errorMessage = "No account found with this email.";
          break;
        case 'wrong-password':
          _errorMessage = "Incorrect password.";
          break;
        case 'invalid-email':
          _errorMessage = "Invalid email format.";
          break;
        case 'user-disabled':
          _errorMessage = "This account has been disabled.";
          break;
        default:
          _errorMessage = e.message ?? "Login failed. Please try again.";
      }
      _setLoading(false);
      return false;

    } on RegisterFailure catch (e) {
      // If Coordinator throws our custom domain exception
      _errorMessage = e.message;
      _setLoading(false);
      return false;

    } catch (e) {
      // Catch-all for unexpected errors
      _errorMessage = "An unexpected error occurred. Please check your connection.";
      _setLoading(false);
      return false;
    }
  }

  // --- INTERNAL HELPERS ---

  /// Updates the loading state and notifies listeners to rebuild the UI.
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