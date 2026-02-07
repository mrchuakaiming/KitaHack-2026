import 'package:flutter/material.dart';

// [IMPORT] Analytics Service for logging page views
import 'services/analytics_service.dart';

// [IMPORT] View Screens
import 'view/login.dart';
import 'view/verify_email.dart';
import 'view/register.dart';
import 'view/home.dart';
import 'view/room.dart';
import 'view/settings_page.dart';
import 'view/reset_password.dart';

/// **AppRoutes Registry**
/// ----------------------------------------------------------------------------
/// This class serves as the central directory for all navigation paths (routes)
/// in the application.
///
/// **Architecture Note:**
/// Instead of defining routes directly in `main.dart`, we centralize them here.
/// This makes the routing table easier to read and maintain.
///
/// **Analytics Integration:**
/// Each route is wrapped in a custom `_PageTracker` widget. This wrapper
/// automatically calls [AnalyticsService.logPageView] whenever the user
/// navigates to a new screen.
/// ----------------------------------------------------------------------------
class AppRoutes {
  
  /// A map of "Route Name" -> "Widget Builder".
  /// Passed to [MaterialApp.routes].
  static Map<String, Widget Function(BuildContext)> routes = {
    
    // ========================================================================
    // AUTHENTICATION FLOW
    // ========================================================================
    
    /// **Login Screen**
    /// The entry point for unauthenticated users.
    '/login': (context) => const _PageTracker(
      pageName: 'login_screen', 
      child: LoginPage()
    ),
    
    /// **Step 1: Verify Email**
    /// Captures Email/Password to create the Auth User.
    /// Separated from profile creation to secure the account ID first.
    '/verify_email': (context) => const _PageTracker(
      pageName: 'verify_email_screen', 
      child: VerifyEmailPage()
    ), 
    
    /// **Step 2: Profile Registration**
    /// Captures Username, Dietary Restrictions, etc.
    /// Only accessible after Email/Password are verified.
    '/register': (context) => const _PageTracker(
      pageName: 'register_screen', 
      child: RegisterPage()
    ),
    
    /// **Reset Password**
    /// A standalone flow for account recovery.
    '/reset_password': (context) => const _PageTracker(
      pageName: 'reset_password_screen', 
      child: ResetPasswordPage()
    ),

    // ========================================================================
    // CORE APPLICATION FLOW
    // ========================================================================
    
    /// **Home Dashboard**
    /// The main landing page for authenticated users.
    /// Allows creating new rooms or viewing history.
    '/home': (context) => const _PageTracker(
      pageName: 'home_dashboard', 
      child: HomePage()
    ),
    
    /// **Active Room Session**
    /// The core interactive screen where users vote/swipe.
    /// Expects a `roomId` to be passed via arguments.
    '/room': (context) => const _PageTracker(
      pageName: 'room_session', 
      child: RoomPage()
    ),
    
    // ========================================================================
    // USER MANAGEMENT
    // ========================================================================
    
    /// **Settings / Profile**
    /// Allows updating profile data or deleting the account.
    '/settings': (context) => const _PageTracker(
      pageName: 'settings_screen', 
      child: SettingsPage()
    ),
  };
}

// ==============================================================================
// INTERNAL ANALYTICS WRAPPER
// ==============================================================================

/// **_PageTracker Widget**
///
/// **Purpose:**
/// Automatically logs a "page_view" event to Firebase Analytics whenever
/// the wrapped widget is inserted into the widget tree.
///
/// **Why is this necessary?**
/// 1.  **Automation:** Developers don't need to manually call `logPageView` inside
///     the `initState` of every single page (Login, Home, Room, etc.).
/// 2.  **Consistency:** Ensures every screen navigation is tracked with a
///     standardized naming convention.
/// 3.  **Performance:** Uses `StatefulWidget` to ensure the log is sent exactly
///     once per page load (inside `initState`), avoiding duplicate logs during
///     rebuilds.
class _PageTracker extends StatefulWidget {
  /// The human-readable name of the screen (e.g., 'home_dashboard').
  /// This name will appear in the Firebase Analytics Console.
  final String pageName;

  /// The actual screen widget to display (e.g., [HomePage]).
  final Widget child;

  const _PageTracker({
    required this.pageName,
    required this.child,
  });

  @override
  State<_PageTracker> createState() => _PageTrackerState();
}

class _PageTrackerState extends State<_PageTracker> {
  /// **Lifecycle Method: initState**
  /// Called exactly once when this widget is first built.
  /// This is the perfect place to trigger the analytics event.
  @override
  void initState() {
    super.initState();
    
    // Call the Singleton AnalyticsService to log the view.
    // We do not await this because we don't want to block the UI rendering.
    AnalyticsService().logPageView(pageName: widget.pageName);
  }

  @override
  Widget build(BuildContext context) {
    // Simply render the child widget (the actual page).
    // This wrapper is visually invisible.
    return widget.child;
  }
}