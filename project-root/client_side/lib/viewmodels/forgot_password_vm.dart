import 'package:flutter/material.dart';

class ForgotPasswordViewModel extends ChangeNotifier {
  // --- STATE ---
  bool _isLoading = false;
  String? _errorMessage;
  bool _isVerified = false; // Tracks if the email link was sent

  // --- GETTERS ---
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isVerified => _isVerified;

  // --- FUNCTIONS ---

  /// Sends the recovery link.
  /// NAMING: Named 'verifyEmail' to avoid conflict with 'resetPassword'.
  Future<void> verifyEmail(String email) async {
    _errorMessage = null;
    _isVerified = false;

    if (email.isEmpty || !email.contains('@')) {
      _errorMessage = "Please enter a valid email address.";
      notifyListeners();
      return;
    }

    _setLoading(true);

    // TODO: Call FirebaseAuth.instance.sendPasswordResetEmail(email: email)
    await Future.delayed(const Duration(seconds: 1)); // Simulate Network

    // SIMULATION: Success
    _isVerified = true;
    
    _setLoading(false);
  }

  // --- HELPER ---
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}