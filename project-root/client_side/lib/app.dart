import 'package:flutter/material.dart';

// View Imports
import 'view/login.dart';
import 'view/verify_email.dart';
import 'view/register.dart';
import 'view/home.dart';
import 'view/room.dart';
import 'view/settings_page.dart';
import 'view/reset_password.dart';

/// A central registry for all named routes in the application.
class AppRoutes {
  static Map<String, Widget Function(BuildContext)> routes = {
    
    // --- AUTHENTICATION FLOW ---
    '/login': (context) => const LoginPage(),
    
    // Step 1: Email/Password Verification
    '/verify_email': (context) => const VerifyEmailPage(), // NEW ROUTE
    
    // Step 2: Profile Completion
    '/register': (context) => const RegisterPage(),
    
    '/reset_password': (context) => const ResetPasswordPage(),

    // --- CORE APPLICATION FLOW ---
    '/home': (context) => const HomePage(),
    '/room': (context) => const RoomPage(),
    
    // --- USER MANAGEMENT ---
    '/settings': (context) => const SettingsPage(),
  };
}