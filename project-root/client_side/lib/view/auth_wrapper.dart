import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../view/home.dart';
import '../view/login.dart';

/// A widget that manages the root navigation flow based on authentication state.
///
/// The [AuthWrapper] listens to the Firebase Authentication stream and automatically
/// switches the visible screen between [HomePage] and [LoginPage].
///
/// Usage:
/// This widget is typically assigned to the `home` property of the `MaterialApp`
/// in `main.dart`, acting as the gatekeeper for the entire application.
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  /// Builds the widget tree based on the current [User] state.
  ///
  /// Uses a [StreamBuilder] to listen to [AuthService.authStateChanges]:
  /// * **ConnectionState.waiting**: Shows a loading indicator while Firebase restores the session.
  /// * **User is logged in**: Renders [HomePage].
  /// * **User is logged out**: Renders [LoginPage].
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // 1. Listen to the real-time auth stream from Firebase
      stream: AuthService().authStateChanges(),
      builder: (context, snapshot) {
        
        // 2. Loading State
        // Firebase is checking local storage for a saved token.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 3. Authenticated State
        // We have valid user data, so we let them in.
        if (snapshot.hasData) {
          return const HomePage(); 
        } 
        
        // 4. Unauthenticated State
        // No user found, show the login screen.
        else {
          return const LoginPage(); 
        }
      },
    );
  }
}