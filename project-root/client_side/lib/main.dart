import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';

// Import all ViewModels
import 'viewmodels/login_vm.dart';
import 'viewmodels/register_vm.dart';
import 'viewmodels/home_vm.dart';
import 'viewmodels/room_vm.dart';
import 'viewmodels/settings_page_vm.dart';
import 'viewmodels/reset_password_vm.dart';

/// The entry point of the application.
///
/// This function initializes the Flutter bindings and runs the app.
/// It wraps the entire application in a [MultiProvider] to ensure that
/// all ViewModels (State Management) are accessible from anywhere in the widget tree.
void main() {
  runApp(
    // MultiProvider is a cleaner way to nest multiple Providers.
    // Instead of nesting Provider<A>(child: Provider<B>(child: ...)), we pass a list.
    MultiProvider(
      providers: [
        // 1. Login State: Handles authentication, errors, and loading during sign-in.
        ChangeNotifierProvider(create: (_) => LoginViewModel()),
        
        // 2. Registration State: Handles new user creation and form validation.
        ChangeNotifierProvider(create: (_) => RegisterViewModel()),
        
        // 3. Home/Dashboard State: Manages the list of hosted rooms and joining logic.
        ChangeNotifierProvider(create: (_) => HomeViewModel()),
        
        // 4. Active Room State: Manages the Lobby, preferences, budget, and live results.
        ChangeNotifierProvider(create: (_) => RoomViewModel()),
        
        // 5. Settings State: Handles profile updates, password changes, and data clearing.
        ChangeNotifierProvider(create: (_) => SettingsViewModel()),
        
        // 6. Password Reset State: Handles sending recovery emails via Firebase.
        ChangeNotifierProvider(create: (_) => ResetPasswordViewModel()),
      ],
      // The root widget of our application
      child: const MyApp(),
    ),
  );
}

/// The Root Widget of the application.
///
/// [MyApp] is responsible for setting up the global configuration for the app,
/// including the design theme, routing logic, and the title.
/// It does not hold state itself, relying on the Providers above it for logic.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'What2Eat',
      
      // --- THEME CONFIGURATION ---
      // We use Material 3 (the latest design system from Google).
      // 'colorScheme.fromSeed' automatically generates a palette of compatible
      // colors based on our primary brand color (Sunset Orange: 0xFFFF7043).
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF7043)),
        useMaterial3: true,
        // Sets a light grey background globally to make white cards "pop".
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      ),
      
      // --- ROUTING CONFIGURATION ---
      // 'initialRoute' determines which screen loads first.
      // We start at '/login' (in a real app, AuthWrapper might decide this).
      initialRoute: '/login',
      
      // 'routes' is a map of String paths to Widget builders.
      // We import this map from 'app.dart' to keep main.dart clean.
      routes: AppRoutes.routes,
    );
  }
}