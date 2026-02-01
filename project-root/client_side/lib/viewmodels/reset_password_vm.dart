import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../coordinators/coordinator.dart';

/// The ViewModel for the Password Reset Screen.
///
/// This class acts as the bridge between the [ResetPasswordPage] UI and the
/// business logic in [Coordinator].
///
/// **Responsibilities:**
/// 1.  **State Management:** Tracks `isLoading`, `isSuccess`, and `errorMessage`.
/// 2.  **Action Delegation:** Calls [Coordinator.resetPassword].
/// 3.  **Error Handling:** Catches [RegisterFailure] and formats messages for the UI.
class ResetPasswordViewModel extends ChangeNotifier {
  
  // --- DEPENDENCIES ---
  final Coordinator _coordinator;

  // --- STATE ---
  
  /// Indicates if the network request is currently active.
  bool _isLoading = false;

  /// Indicates if the email was successfully sent.
  /// Used by the View to show a confirmation dialog or navigation.
  bool _isSuccess = false;

  /// Stores error messages (e.g., "User not found") for UI display.
  String? _errorMessage;

  // --- CONSTRUCTOR ---
  ResetPasswordViewModel({Coordinator? coordinator}) 
      : _coordinator = coordinator ?? Coordinator();

  // --- GETTERS ---
  bool get isLoading => _isLoading;
  bool get isSuccess => _isSuccess;
  String? get errorMessage => _errorMessage;

  // --- FUNCTIONS ---

  /// Triggers the password reset email logic.
  ///
  /// **Parameters:**
  /// * [email]: The email address entered by the user.
  ///
  /// **Logic:**
  /// 1. Validates input locally.
  /// 2. Calls [Coordinator.resetPassword].
  /// 3. Updates [_isSuccess] on completion.
  Future<void> resetPassword(String email) async {
    _setLoading(true);
    _clearState();

    // 1. Basic Local Validation
    if (email.isEmpty || !email.contains('@')) {
      _errorMessage = "Please enter a valid email address.";
      _setLoading(false);
      return;
    }

    try {
      // 2. Delegate to Coordinator
      await _coordinator.resetPassword(email);
      
      // 3. Update Success State
      _isSuccess = true;

    } on RegisterFailure catch (e) {
      // Handle domain-specific errors thrown by Coordinator
      _errorMessage = e.message;
    } on FirebaseAuthException catch (e) {
      // Handle raw Firebase errors if they slip through
      _errorMessage = e.message ?? "Failed to send reset email.";
    } catch (e) {
      // Catch-all
      _errorMessage = "An unexpected error occurred.";
    } finally {
      _setLoading(false);
    }
  }

  // --- INTERNAL HELPERS ---

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _clearState() {
    _errorMessage = null;
    _isSuccess = false;
    notifyListeners();
  }
}