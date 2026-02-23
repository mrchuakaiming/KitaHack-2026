import 'package:flutter/material.dart';

// [IMPORT] Analytics Service
// Used to log 'screen_view' events to Firebase Analytics automatically.
import 'services/analytics_service.dart';

// [IMPORT] View Screens
// Each import corresponds to a specific page in the application.
// Ensure these files exist in your 'lib/view/' directory.
import 'view/login.dart';
import 'view/verify_email.dart';
import 'view/register.dart';
import 'view/home.dart';
import 'view/room.dart'; // Contains the 'RoomPage' class
import 'view/settings_page.dart';
import 'view/reset_password.dart';

/// **AppRoutes Registry**
/// ----------------------------------------------------------------------------
/// This class serves as the central directory for all navigation paths (routes)
/// in the application.
///
/// **Architecture Note:**
/// Instead of defining routes directly in `main.dart`, we centralize them here.
/// This separates the "Configuration" of routes from the "Initialization" of the app.
///
/// **Analytics Integration:**
/// Each route is wrapped in a custom `_PageTracker` widget. This wrapper
/// automatically calls [AnalyticsService.logPageView] whenever the user
/// navigates to a new screen, ensuring consistent data tracking without
/// manual logging code in every widget.
/// ----------------------------------------------------------------------------
class AppRoutes {
  
  /// A static map linking "Route Name Strings" to "Widget Builder Functions".
  /// This map is passed directly to the `routes` property of [MaterialApp].
  static Map<String, Widget Function(BuildContext)> routes = {
    
    // ========================================================================
    // 1. AUTHENTICATION FLOW
    // ========================================================================
    
    /// **Login Screen** (`/login`)
    /// - **Purpose:** The entry point for unauthenticated users.
    /// - **Logic:** Handles Google Sign-In and Email/Password authentication.
    '/login': (context) => const _PageTracker(
      pageName: 'login_screen', 
      child: LoginPage(),
    ),
    
    /// **Verify Email Screen** (`/verify_email`)
    /// - **Purpose:** Step 1 of the sign-up process.
    /// - **Logic:** Captures Email and Password to create the Firebase Auth User.
    ///   This is separated from profile creation to ensure the account exists
    ///   before we try to write profile data to Firestore.
    '/verify_email': (context) => const _PageTracker(
      pageName: 'verify_email_screen', 
      child: VerifyEmailPage(),
    ), 
    
    /// **Registration / Profile Creation** (`/register`)
    /// - **Purpose:** Step 2 of the sign-up process.
    /// - **Logic:** Captures the Username, Dietary Restrictions, and Preferences.
    ///   Only accessible after the user has successfully created an Auth account.
    '/register': (context) => const _PageTracker(
      pageName: 'register_screen', 
      child: RegisterPage(),
    ),
    
    /// **Reset Password** (`/reset_password`)
    /// - **Purpose:** A standalone flow for account recovery.
    /// - **Logic:** Sends a password reset email via Firebase Auth.
    /// '/reset_password': (context) => const _PageTracker(
    ///  pageName: 'reset_password_screen', 
    ///  child: ResetPasswordPage(),
    /// ),

    // ========================================================================
    // 2. CORE APPLICATION FLOW
    // ========================================================================
    
    /// **Home Dashboard** (`/home`)
    /// - **Purpose:** The main landing page for authenticated users.
    /// - **Logic:** Displays the user's active rooms ("What2Eat" sessions) and
    ///   allows creating new rooms or joining existing ones via ID.
    '/home': (context) => const _PageTracker(
      pageName: 'home_dashboard', 
      child: HomePage(),
    ),
    
    /// **Active Room Session** (`/room`)
    /// - **Purpose:** The core interactive screen (Lobby).
    /// - **Logic:** Where users vote on cuisines, search for restaurants, and
    ///   view the final AI recommendation.
    /// - **Arguments:** Expects a `roomId` string passed via `Navigator.pushNamed`.
    '/room': (context) => const _PageTracker(
      pageName: 'room_session', 
      child: RoomPage(), // Ensure class in room.dart is named RoomPage
    ),
    
    // ========================================================================
    // 3. USER MANAGEMENT
    // ========================================================================
    
    /// **Settings / Profile** (`/settings`)
    /// - **Purpose:** User account management.
    /// - **Logic:** Allows updating profile data, preferences, or deleting the account.
    '/settings': (context) => const _PageTracker(
      pageName: 'settings_screen', 
      child: SettingsPage(),
    ),
  };
}

// ==============================================================================
// INTERNAL ANALYTICS WRAPPER
// ==============================================================================

/// **_PageTracker Widget**
///
/// **Purpose:**
/// An internal utility widget that wraps every screen in the app. Its sole job
/// is to log a "page_view" event to Firebase Analytics whenever the widget
/// is built (initialized).
///
/// **Why use a Wrapper?**
/// 1.  **Automation:** Developers don't need to manually call `logPageView` inside
///     the `initState` of every single page (Login, Home, Room, etc.).
/// 2.  **Consistency:** Ensures every screen navigation is tracked with a
///     standardized naming convention (snake_case).
/// 3.  **Separation of Concerns:** Keeps the tracking logic out of the View files.
class _PageTracker extends StatefulWidget {
  /// The human-readable name of the screen (e.g., 'home_dashboard').
  /// This name will appear in the Firebase Analytics Console > Events.
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
  /// Called exactly once when this widget is inserted into the tree.
  /// This is the standard place to trigger "Page Load" events.
  @override
  void initState() {
    super.initState();
    
    // Call the Singleton AnalyticsService to log the view.
    // We do not await this future because analytics logging is a fire-and-forget
    // operation that should not block the UI rendering thread.
    AnalyticsService().logPageView(pageName: widget.pageName);
  }

  @override
  Widget build(BuildContext context) {
    // Simply render the child widget (the actual page).
    // This wrapper is visually invisible to the user.
    return widget.child;
  }
}