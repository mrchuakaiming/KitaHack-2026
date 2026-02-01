import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../coordinators/coordinator.dart';
import '../models/user.dart';

/// The ViewModel for the Registration Flow.
///
/// This class acts as a state-holder and adapter between the View (UI) and the
/// [Coordinator] (Business Logic).
///
/// **Responsibilities:**
/// 1.  **State Management:** Tracks `isLoading` and `errorMessage`.
/// 2.  **Data Transformation:** Converts raw string inputs from TextFields into [UserModel] objects.
/// 3.  **Error Handling:** Catches [RegisterFailure] from the Coordinator and formats messages for the UI.
class RegisterViewModel extends ChangeNotifier {
  
  // --- DEPENDENCIES ---
  final Coordinator _coordinator;

  // --- STATE ---
  bool _isLoading = false;
  String? _errorMessage;

  // --- CONSTRUCTOR ---
  /// Dependency injection allows for easier testing by mocking the Coordinator.
  RegisterViewModel({Coordinator? coordinator}) 
      : _coordinator = coordinator ?? Coordinator();

  // --- GETTERS ---
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // ====================================================================
  // 1. VERIFY EMAIL (Step 1 of Split Flow)
  // ====================================================================

  /// Calls [Coordinator.createUser] to create the Auth account and seed the database.
  ///
  /// This corresponds to the "Next Step" button on the [VerifyEmailPage].
  ///
  /// **Parameters:**
  /// * [email]: User input email.
  /// * [password]: User input password.
  ///
  /// **Returns:**
  /// * `true` if successful (User is authenticated).
  /// * `false` if failed (Check [errorMessage]).
  Future<bool> verifyEmail(String email, String password) async {
    _setLoading(true);
    _clearError();

    try {
      // Coordinator handles Auth + Minimal Firestore seeding
      await _coordinator.createUser(
        email: email, 
        password: password
      );
      
      _setLoading(false);
      return true;

    } on RegisterFailure catch (e) {
      // Handle known flow errors (e.g., email-already-in-use)
      _errorMessage = e.message;
      _setLoading(false);
      return false;
    } catch (e) {
      _errorMessage = "An unexpected error occurred: ${e.toString()}";
      _setLoading(false);
      return false;
    }
  }

  // ====================================================================
  // 2. UPDATE PROFILE (Step 2 of Split Flow)
  // ====================================================================

  /// Calls [Coordinator.updateProfile] to save user details.
  ///
  /// This corresponds to the "Finish Registration" button on the [RegisterPage].
  ///
  /// **Prerequisite:**
  /// The user must be currently signed in (result of [verifyEmail]).
  ///
  /// **Returns:**
  /// * `true` if Firestore was updated successfully.
  Future<bool> updateProfile({
    required String username,
    required List<String> cuisines,
    required List<String> dietaryRestrictions,
  }) async {
    _setLoading(true);
    _clearError();

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _errorMessage = "No authenticated user found. Please log in again.";
      _setLoading(false);
      return false;
    }

    try {
      // 1. Create a UserModel object from the UI inputs
      // Note: We don't need to pass 'email' or 'hostedRooms' for an update,
      // but the model requires them, so we pass current/empty values.
      // The Coordinator.updateProfile ONLY updates mutable fields.
      final userModel = UserModel(
        uid: user.uid,
        email: user.email ?? '', 
        username: username,
        preferredCuisine: cuisines,
        dietaryRestrictions: dietaryRestrictions,
        hostedRooms: [], // Immutable in this context
      );

      // 2. Delegate to Coordinator
      await _coordinator.updateProfile(updated: userModel);

      _setLoading(false);
      return true;

    } on RegisterFailure catch (e) {
      _errorMessage = e.message;
      _setLoading(false);
      return false;
    } catch (e) {
      _errorMessage = "Failed to save profile: ${e.toString()}";
      _setLoading(false);
      return false;
    }
  }

  // ====================================================================
  // 3. LOG IN (Direct Access)
  // ====================================================================

  /// Calls [Coordinator.logIn] to authenticate an existing user.
  ///
  /// **Returns:**
  /// * `true` if login was successful.
  Future<bool> logIn(String email, String password) async {
    _setLoading(true);
    _clearError();

    try {
      await _coordinator.logIn(email: email, password: password);
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      // Basic mapping if not caught by Coordinator's RegisterFailure
      _errorMessage = e.message ?? "Login failed.";
      _setLoading(false);
      return false;
    } catch (e) {
      _errorMessage = "Login error: ${e.toString()}";
      _setLoading(false);
      return false;
    }
  }

  // ====================================================================
  // 4. REGISTER USER (Single-Step / Master Flow)
  // ====================================================================

  /// Calls [Coordinator.registerUser] to perform the entire flow in one go.
  ///
  /// Use this if you want to combine Step 1 and Step 2 into a single form
  /// in the future.
  Future<bool> registerUser({
    required String email,
    required String password,
    required String username,
    required List<String> cuisines,
    required List<String> dietary,
  }) async {
    _setLoading(true);
    _clearError();

    try {
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