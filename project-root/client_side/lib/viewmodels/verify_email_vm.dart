import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// The ViewModel for Step 1 of registration (Credential Verification).
///
/// This class interacts directly with [FirebaseAuth] to create the raw user account.
/// It separates the concern of "Authentication" (Email/Pass) from "User Profile" (Firestore).
class VerifyEmailViewModel extends ChangeNotifier {
  
  // --- STATE ---
  bool _isLoading = false;
  String? _errorMessage;

  // --- GETTERS ---
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // --- FUNCTIONS ---

  /// Attempts to create a new user in Firebase Auth.
  ///
  /// Returns `true` if account creation was successful (or user is now signed in).
  /// Returns `false` if an error occurred (e.g., email already in use).
  Future<bool> createAuthUser(String email, String password) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      // 1. Create User in Firebase Auth
      // This automatically signs the user in upon success.
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      
      _setLoading(false);
      return true;

    } on FirebaseAuthException catch (e) {
      // Handle standard Firebase errors
      switch (e.code) {
        case 'email-already-in-use':
          _errorMessage = "This email is already registered.";
          break;
        case 'invalid-email':
          _errorMessage = "Invalid email format.";
          break;
        case 'weak-password':
          _errorMessage = "Password is too weak.";
          break;
        default:
          _errorMessage = e.message ?? "Authentication failed.";
      }
      _setLoading(false);
      return false;
      
    } catch (e) {
      _errorMessage = "An unexpected error occurred.";
      _setLoading(false);
      return false;
    }
  }

  // --- HELPER ---
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}