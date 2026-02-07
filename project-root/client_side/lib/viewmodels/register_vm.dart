import 'package:flutter/material.dart';
// [IMPORT] Business Logic & Services
import '../coordinators/coordinator.dart';
import '../services/analytics_service.dart';

/// The ViewModel for the Registration Screen.
///
/// **Role:**
/// Acts as the bridge between the [RegisterPage] UI and the backend [Coordinator].
///
/// **Responsibilities:**
/// 1.  **Atomic Delegation:** Calls the master `registerUser` flow.
/// 2.  **Analytics:** Logs the `sign_up` event and identifies the user on success.
/// 3.  **Error Handling:** Catches and exposes `RegisterFailure` messages.
class RegisterViewModel extends ChangeNotifier {
  
  // --- DEPENDENCIES ---
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
  // REGISTER USER (Atomic Action)
  // ====================================================================

  /// Orchestrates the full registration flow.
  ///
  /// **Flow:**
  /// 1. Sets loading state.
  /// 2. Calls [Coordinator.registerUser] (Auth + Firestore + Profile).
  /// 3. **Analytics (Success):**
  ///    - Sets the user ID via [AnalyticsService].
  ///    - Logs the `sign_up` event.
  /// 4. **Error Handling:**
  ///    - Updates `_errorMessage` with human-readable text.
  ///
  /// **Returns:** `true` if successful, `false` otherwise.
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
      // 1. DELEGATE TO COORDINATOR
      // This performs the strict order: Auth -> Profile -> Login
      final result = await _coordinator.registerUser(
        email: email,
        password: password,
        username: username,
        preferredCuisine: cuisines ?? [],
        dietaryRestrictions: dietary ?? [],
      );

      // 2. ANALYTICS (Success)
      // Identify the user for future events
      await AnalyticsService().setUserId(result.user.uid);
      
      // Log the standard Firebase 'sign_up' event
      await AnalyticsService().logEvent(
        'sign_up', 
        params: {'method': 'email_password'}
      );
      
      // Optional: Set user properties for segmentation
      if (result.user.preferredCuisine.isNotEmpty) {
        // e.g., segment users by their top cuisine preference
        await AnalyticsService().setUserProperty(
          name: 'top_cuisine', 
          value: result.user.preferredCuisine.first
        );
      }

      _setLoading(false);
      return true;

    } on RegisterFailure catch (e) {
      // 3. HANDLE DOMAIN ERRORS
      // e.g., "Email already in use"
      _errorMessage = e.message;
      _setLoading(false);
      return false;

    } catch (e) {
      // 4. HANDLE UNEXPECTED ERRORS
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