import 'package:flutter/material.dart';

class RegisterViewModel extends ChangeNotifier {
  // --- STATE ---
  bool _isLoading = false;
  String? _errorMessage;

  // --- GETTERS ---
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // --- FUNCTIONS ---

  /// 1. Verify if email is valid and not already taken
  Future<bool> verifyEmail(String email) async {
    _setLoading(true);
    
    // TODO: Call AuthService.checkEmailAvailability(email)
    // TODO: Validate email format using regex or Model logic
    await Future.delayed(const Duration(milliseconds: 500)); // Simulate network

    // Mock validation logic
    if (email.contains("error")) {
      _errorMessage = "Email is already in use.";
      _setLoading(false);
      return false;
    }

    _errorMessage = null;
    _setLoading(false);
    return true;
  }

  /// 2. Create the Authentication User (Firebase Auth, etc.)
  Future<bool> registerUser({required String email, required String password}) async {
    _setLoading(true);

    // TODO: Call AuthService.signUp(email, password)
    // TODO: Handle FirebaseAuthException (weak password, etc.)
    await Future.delayed(const Duration(seconds: 1)); // Simulate network

    _setLoading(false);
    return true; // Return true if Auth ID is created successfully
  }

  /// 3. Add details to the Database (Firestore, etc.)
  Future<bool> updateProfile({
    required String username, 
    required List<String> cuisines, 
    required List<String> restrictions
  }) async {
    _setLoading(true);

    // TODO: Get current User ID from AuthService
    // TODO: Call UserService.createProfile(uid, username, cuisines, restrictions)
    await Future.delayed(const Duration(seconds: 1)); // Simulate network

    _setLoading(false);
    return true;
  }

  /// 4. Auto-Login after successful registration
  Future<bool> logIn(String email, String password) async {
    _setLoading(true);

    // TODO: Call AuthService.signIn(email, password) to get the session token
    // TODO: Initialize User Session / Global State
    await Future.delayed(const Duration(milliseconds: 500)); 

    _setLoading(false);
    return true;
  }

  // --- HELPER ---
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}