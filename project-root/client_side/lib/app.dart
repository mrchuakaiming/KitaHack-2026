import 'package:flutter/material.dart';

// [IMPORT] Analytics Service
import 'services/analytics_service.dart';

// [IMPORT] View Screens
import 'view/login.dart';
import 'view/verify_email.dart';
import 'view/register.dart';
import 'view/home.dart';
import 'view/room.dart'; 
import 'view/settings_page.dart';
import 'view/reset_password.dart';

/// ==============================================================================
/// ROUTING REGISTRY
/// ==============================================================================
/// Centralized directory for all navigation paths (routes) in the application.
///
/// **Architecture Note:**
/// Separating the routing table from `main.dart` keeps the codebase clean and 
/// makes adding new screens highly scalable.
class AppRoutes {
  
  /// A static map linking "Route Name Strings" to "Widget Builder Functions".
  static Map<String, Widget Function(BuildContext)> routes = {
    
    // ========================================================================
    // 1. AUTHENTICATION FLOW
    // ========================================================================
    
    /// **Login Screen** (`/login`)
    /// Entry point for unauthenticated users. Handles Email/Password auth.
    '/login': (context) => const _PageTracker(
      pageName: 'login_screen', 
      child: LoginPage(),
    ),
    
    /// **Verify Email Screen** (`/verify_email`)
    /// Step 1 of sign-up. Captures Email/Password to create Auth User.
    '/verify_email': (context) => const _PageTracker(
      pageName: 'verify_email_screen', 
      child: VerifyEmailPage(),
    ), 
    
    /// **Registration / Profile Creation** (`/register`)
    /// Step 2 of sign-up. Captures Username and dietary preferences.
    '/register': (context) => const _PageTracker(
      pageName: 'register_screen', 
      child: RegisterPage(),
    ),
    
    /// **Reset Password** (`/reset_password`)
    /// Standalone flow for account recovery. Triggers Firebase password reset emails.
    // UNCOMMENTED: Fully integrated into the routing table.
    '/reset_password': (context) => const _PageTracker(
     pageName: 'reset_password_screen', 
     child: ResetPasswordPage(),
    ),

    // ========================================================================
    // 2. CORE APPLICATION FLOW
    // ========================================================================
    
    /// **Home Dashboard** (`/home`)
    /// Landing page for authenticated users to manage and join active rooms.
    '/home': (context) => const _PageTracker(
      pageName: 'home_dashboard', 
      child: HomePage(),
    ),
    
    /// **Active Room Session** (`/room`)
    /// Core interactive lobby where users vote, search, and get AI recommendations.
    '/room': (context) => const _PageTracker(
      pageName: 'room_session', 
      child: RoomPage(), 
    ),
    
    // ========================================================================
    // 3. USER MANAGEMENT
    // ========================================================================
    
    /// **Settings / Profile** (`/settings`)
    /// User account management (updating preferences, deleting account).
    '/settings': (context) => const _PageTracker(
      pageName: 'settings_screen', 
      child: SettingsPage(),
    ),
  };
}

/// ==============================================================================
/// INTERNAL ANALYTICS WRAPPER
/// ==============================================================================
/// An internal utility widget that wraps every screen in the app. 
/// Its sole job is to seamlessly log a "page_view" event to Firebase Analytics 
/// whenever the widget is mounted.
class _PageTracker extends StatefulWidget {
  final String pageName;
  final Widget child;

  const _PageTracker({
    required this.pageName,
    required this.child,
  });

  @override
  State<_PageTracker> createState() => _PageTrackerState();
}

class _PageTrackerState extends State<_PageTracker> {
  
  @override
  void initState() {
    super.initState();
    // Fire-and-forget logging to avoid blocking the UI thread during navigation.
    AnalyticsService().logPageView(pageName: widget.pageName);
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}