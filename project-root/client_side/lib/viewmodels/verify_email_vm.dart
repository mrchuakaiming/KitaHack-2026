import 'package:flutter/material.dart';

/// **ViewModel for Step 1: Credential Verification**
///
/// **Architectural Role:**
/// This ViewModel acts as a **Strict Data Validator** for the first step of registration.
///
/// **Why no Firebase?**
/// Based on the "Pass-Forward" architecture, we do **NOT** create the account here.
/// We only validate the input format to ensure the user doesn't waste time on
/// Step 2 if their password is too weak or email is invalid.
///
/// **Responsibilities:**
/// 1.  **Input Validation:** Enforces Regex rules for Email and complex Password policies.
/// 2.  **State Management:** Holds temporary error messages for the UI.
class VerifyEmailViewModel extends ChangeNotifier {
  
  // ====================================================================
  // STATE PROPERTIES
  // ====================================================================

  /// Stores validation error messages to be displayed in the UI.
  /// Examples: "Password must contain a number", "Invalid email format".
  /// `null` implies the input is currently valid.
  String? _errorMessage;

  // ====================================================================
  // GETTERS
  // ====================================================================

  String? get errorMessage => _errorMessage;

  // ====================================================================
  // ACTIONS
  // ====================================================================

  /// Validates the user's input against strict security policies.
  ///
  /// **Password Policy:**
  /// - Length: 8 to 64 characters.
  /// - Must contain at least one number (0-9).
  /// - Must contain at least one uppercase letter (A-Z).
  /// - Must contain at least one lowercase letter (a-z).
  /// - Must contain at least one special character (!@#\$&*~ etc).
  ///
  /// **Parameters:**
  /// * [email]: The input email string.
  /// * [password]: The input password string.
  /// * [confirmPassword]: The confirmation password string.
  ///
  /// **Returns:** `true` if inputs are valid and ready for Step 2.
  bool validateInput({
    required String email, 
    required String password, 
    required String confirmPassword
  }) {
    _clearError();
    
    // ------------------------------------------------------------------
    // 1. EMAIL VALIDATION
    // ------------------------------------------------------------------
    // Standard Regex: text + @ + text + . + text
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (email.isEmpty || !emailRegex.hasMatch(email.trim())) {
      _errorMessage = "Please enter a valid email address.";
      notifyListeners();
      return false;
    }

    // ------------------------------------------------------------------
    // 2. PASSWORD MATCH VALIDATION
    // ------------------------------------------------------------------
    if (password != confirmPassword) {
      _errorMessage = "Passwords do not match.";
      notifyListeners();
      return false;
    }

    // ------------------------------------------------------------------
    // 3. PASSWORD COMPLEXITY VALIDATION
    // ------------------------------------------------------------------
    
    // A. Length Check (8 - 64 characters)
    if (password.length < 8) {
      _errorMessage = "Password must be at least 8 characters.";
      notifyListeners();
      return false;
    }
    if (password.length > 64) {
      _errorMessage = "Password must be less than 64 characters.";
      notifyListeners();
      return false;
    }

    // B. Uppercase Letter Check
    if (!password.contains(RegExp(r'[A-Z]'))) {
      _errorMessage = "Password must contain at least one uppercase letter.";
      notifyListeners();
      return false;
    }

    // C. Lowercase Letter Check
    if (!password.contains(RegExp(r'[a-z]'))) {
      _errorMessage = "Password must contain at least one lowercase letter.";
      notifyListeners();
      return false;
    }

    // D. Number Check
    if (!password.contains(RegExp(r'[0-9]'))) {
      _errorMessage = "Password must contain at least one number.";
      notifyListeners();
      return false;
    }

    // E. Special Character Check
    // Checks for standard special characters
    if (!password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) {
      _errorMessage = "Password must contain a special character (e.g., !@#\$).";
      notifyListeners();
      return false;
    }

    // If we survive all checks, the input is valid.
    return true;
  }

  // ====================================================================
  // INTERNAL HELPERS
  // ====================================================================

  /// Clears any previous error messages to reset UI state.
  void _clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners(); // Notify listeners only if state actually changed
    }
  }
}