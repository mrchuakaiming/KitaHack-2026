import 'package:flutter/material.dart';
import 'view/login.dart';
import 'view/register.dart';
import 'view/home.dart';
import 'view/room.dart';
import 'view/settings_page.dart';
import 'view/reset_password.dart';

/// A central registry for all named routes in the application.
///
/// This class defines the mapping between string paths (e.g., `'/home'`) and
/// their corresponding Widget builders. It abstracts the navigation logic
/// away from `main.dart`, making the code cleaner and easier to manage.
///
/// **Usage:**
/// These routes are passed to the `routes` property of the `MaterialApp` widget.
/// Navigation is then performed using:
/// ```dart
/// Navigator.pushNamed(context, '/route_name');
/// ```
class AppRoutes {
  /// A map of route names to widget builders.
  ///
  /// **Key:** The string path of the route (e.g., `'/login'`).
  /// **Value:** A function that takes a [BuildContext] and returns the [Widget] to display.
  static Map<String, Widget Function(BuildContext)> routes = {
    
    // --- AUTHENTICATION FLOW ---
    
    // The entry point for unauthenticated users.
    // Handles email/password sign-in.
    '/login': (context) => const LoginPage(),
    
    // The account creation screen.
    // Captures user details, cuisines, and dietary restrictions.
    '/register': (context) => const RegisterPage(),
    
    // The password recovery screen.
    // Sends a reset link via email (Firebase Auth).
    '/reset_password': (context) => ResetPasswordPage(),

    // --- CORE APPLICATION FLOW ---

    // The main dashboard.
    // Allows creating new rooms, viewing hosted rooms, and joining via code.
    '/home': (context) => const HomePage(),
    
    // The active session lobby.
    // Where the voting and decision-making happens (Budget, Preferences, Results).
    '/room': (context) => const RoomPage(),
    
    // --- USER MANAGEMENT ---
    
    // The profile settings screen.
    // Handles username updates, clearing history, and account deletion.
    '/settings': (context) => const SettingsPage(),
  };
}