import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// The ViewModel responsible for the Password Reset logic.
///
/// This class acts as the bridge between the UI (ResetPasswordPage) and the
/// backend (Firebase Authentication). It handles:
/// 1. **State Management:** Loading indicators, error messages, and success flags.
/// 2. **Input Validation:** Checking if the email format is valid before sending.
/// 3. **API Integration:** communicating with Firebase to send the recovery email.
/// 4. **Error Handling:** Translating Firebase error codes into user-friendly messages.
class ResetPasswordViewModel extends ChangeNotifier {
  
  // --- STATE ---
  
  /// Indicates if an asynchronous operation (sending email) is currently in progress.
  /// Used to show a spinner or disable the "Send" button in the UI.
  bool _isLoading = false;

  /// Holds the description of any error that occurs during the process.
  /// If null, it means no error has occurred (or the state has been reset).
  String? _errorMessage;

  /// Tracks if the password reset email was successfully sent.
  /// The UI uses this to switch from the "Input Form" to the "Success Message".
  bool _isSuccess = false; 

  // --- GETTERS ---
  // These expose the private state to the UI (read-only).
  
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isSuccess => _isSuccess;

  // --- FUNCTIONS ---

  /// Sends a password reset link to the provided [email] using Firebase Auth.
  ///
  /// This method performs the following steps:
  /// 1. Resets any previous error/success state.
  /// 2. Validates the email locally (checks for empty or missing '@').
  /// 3. Calls the Firebase `sendPasswordResetEmail` method.
  /// 4. Handles specific Firebase exceptions (like user not found) and updates `_errorMessage`.
  /// 5. Updates `_isSuccess` if the call completes without error.
  Future<void> verifyEmail(String email) async {
    _resetState();

    // 1. Local Validation
    // Trimming ensures we don't fail due to accidental leading/trailing spaces.
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      _errorMessage = "Please enter a valid email address.";
      notifyListeners();
      return;
    }

    // Start loading (Update UI to show spinner)
    _setLoading(true);

    try {
      // 2. Firebase Implementation
      // This is the core API call. Firebase handles the generation of the token
      // and sending the email. We don't need to manage the link itself.
      await FirebaseAuth.instance.sendPasswordResetEmail(email: cleanEmail);
      
      // If code reaches here, no exception was thrown.
      // The email was sent (or pending).
      _isSuccess = true;

    } on FirebaseAuthException catch (e) {
      // 3. Handle Specific Firebase Errors
      // Firebase returns specific string codes for known errors. 
      // We map these to friendly messages for the user.
      switch (e.code) {
        case 'user-not-found':
          // Security Note: Some apps prefer not to reveal if a user exists.
          // However, for UX in non-critical apps, telling them "No account" is helpful.
          _errorMessage = "No account found with this email.";
          break;
        case 'invalid-email':
          _errorMessage = "The email address is badly formatted.";
          break;
        case 'too-many-requests':
          // Occurs if the user spans the button.
          _errorMessage = "Too many attempts. Please try again later.";
          break;
        default:
          // Fallback for rare/unknown Firebase errors
          _errorMessage = e.message ?? "An error occurred. Please try again.";
      }
    } catch (e) {
      // Handle generic errors (e.g., No Internet, Network Timeout)
      _errorMessage = "An unexpected error occurred. Please check your connection.";
    } finally {
      // 4. Cleanup
      // Always turn off the loading indicator, regardless of success or failure.
      _setLoading(false);
    }
  }

  // --- HELPERS ---

  /// Clears previous errors and success flags.
  /// Should be called before starting a new attempt.
  void _resetState() {
    _errorMessage = null;
    _isSuccess = false;
    notifyListeners();
  }

  /// Updates the loading state and notifies the UI to rebuild.
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}