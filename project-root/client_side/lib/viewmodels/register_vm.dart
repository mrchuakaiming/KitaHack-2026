import 'package:flutter/material.dart';
import '../coordinators/coordinator.dart';

/// The ViewModel for the Registration Screen.
///
/// **Responsibilities:**
/// 1.  **State Management:** exposure of `isLoading` and `errorMessage`.
/// 2.  **Registration Delegation:** Calls the master [Coordinator.registerUser] method.
class RegisterViewModel extends ChangeNotifier {
  
  final Coordinator _coordinator;

  // --- STATE ---
  bool _isLoading = false;
  String? _errorMessage;

  // --- CONSTRUCTOR ---
  RegisterViewModel({Coordinator? coordinator}) 
      : _coordinator = coordinator ?? Coordinator();

  // --- GETTERS ---
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // ====================================================================
  // REGISTER USER (Master Flow)
  // ====================================================================

  /// Orchestrates the full registration flow (Auth -> Profile -> Login).
  ///
  /// This single function handles:
  /// 1. Creating the Auth User.
  /// 2. Creating the Firestore User Document.
  /// 3. Updating the Profile with Username/Preferences.
  /// 4. Logging the user in.
  ///
  /// **Returns:**
  /// * `true` if the entire flow completes successfully.
  Future<bool> registerUser({
    required String email,
    required String password,
    required String username,
    List<String>? cuisines,
    List<String>? dietary,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      // DELEGATION: The Coordinator handles the complexity of 
      // chaining Auth, Firestore, and Analytics calls.
      await _coordinator.registerUser(
        email: email,
        password: password,
        username: username,
        preferredCuisine: cuisines,
        dietaryRestrictions: dietary,
      );
      
      _setLoading(false);
      return true;

    } on RegisterFailure catch (e) {
      // Pass domain-specific errors (e.g. "Email in use") to the UI
      _errorMessage = e.message;
      _setLoading(false);
      return false;
    } catch (e) {
      _errorMessage = "Registration failed: ${e.toString()}";
      _setLoading(false);
      return false;
    }
  }

  // --- INTERNAL HELPERS ---

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}