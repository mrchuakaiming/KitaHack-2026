// No longer implemented
// import 'package:flutter/material.dart';

// // [IMPORT] Business Logic & Services
// import '../coordinators/coordinator.dart';
// import '../services/analytics_service.dart';

// /// **ViewModel for Password Reset**
// ///
// /// This class manages the state and business logic for the [ResetPasswordPage].
// ///
// /// **Role in MVVM:**
// /// - **State Holder:** Manages `isLoading`, `isSuccess`, and `errorMessage`.
// /// - **Bridge:** Connects the UI to the [Coordinator] for backend operations.
// /// - **Observer:** Logs analytics events for business intelligence.
// ///
// /// **Responsibilities:**
// /// 1.  **Input Validation:** Checks if the email format is valid before sending.
// /// 2.  **Action Delegation:** Calls [Coordinator.resetPassword] to trigger the email.
// /// 3.  **Analytics:** Logs 'password_reset_request' events to track usage.
// /// 4.  **Feedback:** Exposes success/error states for UI alerts.
// class ResetPasswordViewModel extends ChangeNotifier {
  
//   // ====================================================================
//   // DEPENDENCIES
//   // ====================================================================
  
//   /// The Coordinator handles the interaction with Firebase Auth.
//   final Coordinator _coordinator;

//   // ====================================================================
//   // STATE PROPERTIES
//   // ====================================================================
  
//   /// **Loading State**
//   /// `true` when the network request is in flight.
//   /// Used to disable the "Send Email" button and show a progress indicator.
//   bool _isLoading = false;

//   /// **Success State**
//   /// `true` if the reset email was successfully sent.
//   /// Used by the View to show a success dialog or navigate back to Login.
//   bool _isSuccess = false;

//   /// **Error State**
//   /// Contains a human-readable error message if the operation fails.
//   /// `null` if no error has occurred.
//   String? _errorMessage;

//   // ====================================================================
//   // CONSTRUCTOR
//   // ====================================================================
  
//   /// Creates the ViewModel with an optional [Coordinator] for dependency injection.
//   ResetPasswordViewModel({Coordinator? coordinator}) 
//       : _coordinator = coordinator ?? Coordinator();

//   // ====================================================================
//   // GETTERS
//   // ====================================================================
  
//   bool get isLoading => _isLoading;
//   bool get isSuccess => _isSuccess;
//   String? get errorMessage => _errorMessage;

//   // ====================================================================
//   // PUBLIC ACTIONS
//   // ====================================================================

//   /// Triggers the password reset flow.
//   ///
//   /// **Flow:**
//   /// 1.  **Validation:** Checks if the email string is not empty and contains '@'.
//   /// 2.  **Network Call:** Delegates to [Coordinator.resetPassword].
//   /// 3.  **Analytics:** On success, logs a `password_reset_request` event.
//   /// 4.  **State Update:** Sets `isSuccess` to true to notify the UI.
//   ///
//   /// **Parameters:**
//   /// * [email]: The user's input email address.
//   Future<void> resetPassword(String email) async {
//     _setLoading(true);
//     _clearState();

//     // 1. Basic Local Validation
//     // Prevents unnecessary network calls for obviously bad input.
//     final trimmedEmail = email.trim();
//     if (trimmedEmail.isEmpty || !trimmedEmail.contains('@')) {
//       _errorMessage = "Please enter a valid email address.";
//       _setLoading(false);
//       return;
//     }

//     try {
//       // 2. Delegate to Coordinator
//       // The coordinator handles the specific FirebaseAuth call.
//       await _coordinator.resetPassword(trimmedEmail);
      
//       // 3. Analytics Integration
//       // Track that a user requested a password reset.
//       // NOTE: We do NOT log the email address itself to protect user privacy (PII).
//       await AnalyticsService().logEvent(
//         'password_reset_request', 
//         params: {'method': 'email_link'}
//       );

//       // 4. Update Success State
//       _isSuccess = true;
//       // We don't set loading to false here immediately if we want the success 
//       // state to trigger a navigation/dialog while "loading" finishes in the UI.
//       // But typically, we finish loading to enable the UI to react.

//     } catch (e) {
//       // 5. Error Handling
//       // The Coordinator throws a generic Exception with a message.
//       // We strip the "Exception: " prefix if present for cleaner UI.
//       final msg = e.toString().replaceAll("Exception: ", "");
      
//       _errorMessage = msg;
      
//       // Log the failure (optional, but good for debugging issues)
//       debugPrint("Reset Password Failed: $e");
//     } finally {
//       // Always stop loading, regardless of success or failure.
//       _setLoading(false);
//     }
//   }

//   // ====================================================================
//   // INTERNAL HELPERS
//   // ====================================================================

//   /// Updates the `_isLoading` flag and triggers a UI rebuild.
//   void _setLoading(bool value) {
//     _isLoading = value;
//     notifyListeners();
//   }

//   /// Resets the error and success states before a new attempt.
//   void _clearState() {
//     _errorMessage = null;
//     _isSuccess = false;
//     notifyListeners();
//   }
// }