import 'package:flutter/material.dart';

class LoginViewModel extends ChangeNotifier {
  // --- STATE ---
  bool _isLoading = false;
  String? _errorMessage;

  // --- GETTERS ---
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // --- FUNCTIONS ---

  Future<bool> logIn(String email, String password) async {
    _setLoading(true);
    _errorMessage = null; // Reset error before attempt

    // TODO: Validate email format (regex) locally before sending to server
    // TODO: Call AuthService.signIn(email, password)
    // TODO: Handle FirebaseAuthException (e.g., 'user-not-found', 'wrong-password')
    // TODO: Fetch User Profile data from DatabaseService after Auth success
    // TODO: Save session token to SecureStorage for auto-login next time

    // SIMULATION (Remove this when implementing real logic)
    await Future.delayed(const Duration(seconds: 1)); 

    // Mock Logic: Fail if password is "error"
    if (password == "error") {
      _errorMessage = "Invalid email or password.";
      _setLoading(false);
      return false;
    }

    _setLoading(false);
    return true; // Return true if login successful
  }

  // --- HELPER ---
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}