import 'package:flutter/material.dart';

/// ==============================================================================
/// VERIFY EMAIL VIEW MODEL
/// ==============================================================================
/// Acts as the logic layer for the first step of registration. 
/// It performs synchronous validation of the user's email and password before 
/// allowing the UI to proceed to the profile setup (Step 2).
/// ==============================================================================
class VerifyEmailViewModel extends ChangeNotifier {
  
  // --- STATE PROPERTIES ---

  /// Holds the error message to be displayed on the UI. Null means no error.
  String? _errorMessage;

  /// Flag indicating if the current password text meets the strict length requirement.
  bool _hasMinLength = false;

  // --- PUBLIC GETTERS ---

  /// Returns the current error message, if any.
  String? get errorMessage => _errorMessage;

  /// Exposes the password length status to the UI for real-time visual feedback.
  bool get hasMinLength => _hasMinLength;

  // --- ACTIONS & LOGIC ---

  /// Analyzes the password string to check if it meets the 6-character minimum.
  /// 
  /// This is called by a listener in the View every time the user types 
  /// in the password field, providing immediate visual feedback on the checklist.
  ///
  /// [password]: The raw string currently in the password controller.
  void updatePasswordStatus(String password) {
    // [CRITICAL FIX]: We use .trim() here so leading/trailing spaces do not
    // count towards the 6-character minimum. This prevents users from bypassing 
    // the security check by typing "123   ".
    _hasMinLength = password.trim().length >= 6;
    
    // Notify the UI to update the green checkmark indicator
    notifyListeners();
  }

  /// The "Gatekeeper" function for navigation to Step 2.
  /// 
  /// Returns `true` ONLY if:
  /// 1. Email format is correct.
  /// 2. Password is not empty.
  /// 3. Password matches the Confirm Password field perfectly.
  /// 4. Password contains at least 6 non-space characters.
  ///
  /// [email]: The email address provided by the user.
  /// [password]: The primary password chosen.
  /// [confirmPassword]: The verification password.
  bool validateInput({
    required String email, 
    required String password, 
    required String confirmPassword
  }) {
    // Reset error state before running a fresh validation pass
    _errorMessage = null;
    debugPrint("VM: Validating Input..."); 

    // 1. EMAIL VALIDATION
    // Standard regex to check for basic email structure (user@domain.com)
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (email.trim().isEmpty || !emailRegex.hasMatch(email.trim())) {
      _errorMessage = "Please enter a valid email address.";
      notifyListeners();
      return false; // Abort
    }

    // 2. EMPTY PASSWORD VALIDATION
    if (password.trim().isEmpty) {
      _errorMessage = "Password cannot be empty or just spaces.";
      updatePasswordStatus(password); // Force indicator to grey
      notifyListeners();
      return false; // Abort
    }

    // 3. PASSWORD MATCH VALIDATION
    // Compares the exact raw strings (spaces included) to ensure they match
    if (password != confirmPassword) {
      _errorMessage = "Passwords do not match.";
      notifyListeners();
      return false; // Abort
    }

    // 4. STRICT LENGTH VALIDATION
    // Force a fresh check just in case the UI listener missed a frame
    updatePasswordStatus(password);

    if (!_hasMinLength) {
      _errorMessage = "Password must be at least 6 characters long (excluding spaces).";
      notifyListeners();
      debugPrint("VM: Length validation failed (Under 6 valid chars)");
      return false; // Abort
    }

    // --- SUCCESS ---
    debugPrint("VM: Validation Successful. Proceeding to Step 2.");
    _errorMessage = null; 
    notifyListeners(); // Clears any lingering red text on the UI
    
    return true; // Grants permission to navigate
  }
}