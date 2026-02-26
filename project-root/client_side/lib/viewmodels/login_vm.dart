import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../coordinators/coordinator.dart';
import '../services/analytics_service.dart';

/// ==============================================================================
/// LOGIN VIEW MODEL (Presenter/Controller)
/// ==============================================================================
/// Acts as the logic bridge between the [LoginPage] and the backend [Coordinator].
///
/// **Responsibilities:**
/// - Maintains UI state (`isLoading`, `errorMessage`).
/// - Executes the authentication network calls.
/// - Triggers business intelligence tracking via [AnalyticsService].
class LoginViewModel extends ChangeNotifier {
  
  /// The Coordinator acts as a Facade to handle complex Firebase Auth 
  /// and Firestore document fetching sequentially.
  final Coordinator _coordinator;

  /// Determines if the UI should show a loading state and disable inputs.
  bool _isLoading = false;

  /// Holds human-readable error messages caught during the auth flow.
  String? _errorMessage;

  /// Allows dependency injection of the Coordinator (useful for mocking/testing).
  LoginViewModel({Coordinator? coordinator}) 
      : _coordinator = coordinator ?? Coordinator();

  // Getters for the View to observe
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Attempts to authenticate the user and retrieve their Firestore profile.
  ///
  /// Returns `true` if authentication is fully successful, otherwise `false`.
  Future<bool> logIn(String email, String password) async {
    _setLoading(true);
    _clearError();

    try {
      // 1. Authenticate via Coordinator
      final result = await _coordinator.logIn(
        email: email, 
        password: password
      );

      // 2. Link Analytics to the freshly authenticated user
      await AnalyticsService().setUserId(result.user.uid);
      await AnalyticsService().logLogin(method: 'email_password');

      _setLoading(false);
      return true;

    } on RegisterFailure catch (e) {
      // 3. Handle specific domain errors parsed by the Coordinator
      _errorMessage = e.message;
      _setLoading(false);
      return false;

    } on FirebaseAuthException catch (e) {
      // Fallback for raw Firebase exceptions
      _errorMessage = e.message ?? "Authentication failed.";
      _setLoading(false);
      return false;

    } catch (e) {
      // Fallback for network timeouts or parsing crashes
      _errorMessage = "An unexpected error occurred. Please check your connection.";
      debugPrint("LoginVM Error: $e");
      _setLoading(false);
      return false;
    }
  }

  /// Sets the loading flag and forces a UI repaint.
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  /// Clears previous error messages from the screen.
  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}