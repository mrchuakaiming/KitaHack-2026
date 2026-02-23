import 'package:flutter/material.dart';
import '../coordinators/coordinator.dart';
import '../services/analytics_service.dart';

/// ============================================================================
/// REGISTER VIEW MODEL (STEP 2: PROFILE REGISTRATION)
/// ============================================================================
/// **Role:**
/// Acts as the logic layer for the final step of the account creation process.
/// It takes the highly secure credentials passed from Step 1 (Verify Email) 
/// and combines them with the profile preferences (username, dietary, cuisines) 
/// gathered in Step 2. 
/// 
/// It then delegates the actual database writes to the `Coordinator` and 
/// handles the resulting success or failure states (like duplicate emails).
/// ============================================================================
class RegisterViewModel extends ChangeNotifier {
  
  // --- Dependencies ---
  /// The central coordinator that manages Firebase Auth and Firestore interactions.
  final Coordinator _coordinator;

  // --- State Properties ---
  /// Tracks whether a network request is currently active (used to disable buttons and show spinners).
  bool _isLoading = false;
  
  /// Holds any error messages to be displayed on the UI. Null means no error.
  String? _errorMessage;

  // --- Constructor ---
  /// Injects the Coordinator dependency. Creates a default instance if none is provided.
  RegisterViewModel({Coordinator? coordinator}) 
      : _coordinator = coordinator ?? Coordinator();

  // --- Public Getters ---
  /// Exposes the loading state to the UI.
  bool get isLoading => _isLoading;
  
  /// Exposes the current error message to the UI.
  String? get errorMessage => _errorMessage;

  // ===========================================================================
  // ACTION: REGISTER USER
  // ===========================================================================

  /// Orchestrates the full end-to-end registration flow.
  ///
  /// This method performs the final Firebase Authentication account creation 
  /// and writes the user's customized `UserModel` to Firestore.
  ///
  /// [email]: The strictly validated email from Step 1.
  /// [password]: The strictly validated password from Step 1.
  /// [username]: The display name chosen by the user in Step 2.
  /// [cuisines]: An optional list of preferred cuisines.
  /// [dietary]: An optional list of dietary restrictions.
  /// 
  /// Returns `true` if the account was successfully created and the user is signed in.
  /// Returns `false` if the process failed (e.g., email already in use, network error).
  Future<bool> registerUser({
    required String email,
    required String password,
    required String username,
    List<String>? cuisines,
    List<String>? dietary,
  }) async {
    _setLoading(true);
    _clearError();
    debugPrint("RegisterVM: Attempting to register user: $email");

    try {
      // 1. DELEGATE TO COORDINATOR (Backend Integration)
      // The coordinator handles creating the Auth user and the Firestore document
      // as a single, atomic operation to prevent "ghost" accounts.
      final result = await _coordinator.registerUser(
        email: email,
        password: password,
        username: username,
        preferredCuisine: cuisines ?? [],
        dietaryRestrictions: dietary ?? [],
      );

      debugPrint("RegisterVM: Registration Successful. User UID: ${result.user.uid}");

      // 2. LOG ANALYTICS (Success)
      // Link this specific device/session to the newly generated Firebase UID
      await AnalyticsService().setUserId(result.user.uid);
      // Log the successful funnel completion
      await AnalyticsService().logEvent(
        'sign_up', 
        params: {'method': 'email_password'}
      );
      
      _setLoading(false);
      return true; // SUCCESS! The UI can now navigate to the Home screen.

    } on RegisterFailure catch (e) {
      // 3. HANDLE SPECIFIC DOMAIN ERRORS
      // This catches custom errors thrown by our Coordinator.
      
      // [CRITICAL FIX]: Handle Google's 'email-already-in-use' error safely here.
      // This replaces the deprecated fetchSignInMethodsForEmail check from Step 1.
      if (e.code == 'email-already-in-use') {
        _errorMessage = "This email is already registered. Please go back and log in.";
      } else {
        // Fallback for weak passwords, invalid emails, or database write failures
        _errorMessage = e.message;
      }
      
      _setLoading(false);
      debugPrint("RegisterVM: Domain Error - [${e.code}] ${e.message}");
      return false; // Registration failed, keep user on this screen.

    } catch (e) {
      // 4. HANDLE UNEXPECTED ERRORS
      // Catch-all for network drops, timeout exceptions, etc.
      _errorMessage = "Registration failed: ${e.toString()}";
      _setLoading(false);
      debugPrint("RegisterVM: Unexpected Error - $e");
      return false;
    }
  }

  // ===========================================================================
  // STATE MANAGEMENT HELPERS
  // ===========================================================================

  /// Safely updates the loading spinner state and triggers a UI rebuild.
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  /// Clears any lingering red error text from the UI.
  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}