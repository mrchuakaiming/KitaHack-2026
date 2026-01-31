import 'package:flutter/material.dart';

class ChangePasswordViewModel extends ChangeNotifier {
  // --- STATE ---
  bool _isLoading = false;
  String? _errorMessage;

  // --- GETTERS ---
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // --- FUNCTIONS ---

  /// Updates the password for a logged-in user.
  /// NAMING: Specifically named 'resetPassword' as requested.
  Future<bool> resetPassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    _errorMessage = null;

    // 1. Validation
    if (currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      _errorMessage = "All fields are required.";
      notifyListeners();
      return false;
    }

    if (newPassword != confirmPassword) {
      _errorMessage = "New passwords do not match.";
      notifyListeners();
      return false;
    }

    if (newPassword.length < 6) {
      _errorMessage = "New password must be at least 6 characters.";
      notifyListeners();
      return false;
    }

    _setLoading(true);

    // TODO: Call AuthService.reauthenticate(currentPassword)
    // TODO: Call AuthService.updatePassword(newPassword)
    
    await Future.delayed(const Duration(seconds: 1)); // Simulate Network

    // SIMULATION: Fail if current password is "wrong"
    if (currentPassword == "wrong") {
      _errorMessage = "Current password is incorrect.";
      _setLoading(false);
      return false;
    }

    _setLoading(false);
    return true; // Success
  }

  // --- HELPER ---
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}