import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'; 

import 'app.dart';

// ViewModels (State Management)
import 'viewmodels/login_vm.dart';
import 'viewmodels/verify_email_vm.dart';
import 'viewmodels/register_vm.dart';
import 'viewmodels/home_vm.dart';
import 'viewmodels/room_vm.dart';
import 'viewmodels/settings_page_vm.dart';
import 'viewmodels/reset_password_vm.dart';

/// ==============================================================================
/// APPLICATION ENTRY POINT
/// ==============================================================================
/// This function bootstraps the entire Flutter application.
///
/// Responsibilities:
/// 1. Binds the Flutter engine to the framework.
/// 2. Initializes the Firebase SDK with explicit platform options.
/// 3. Injects all ViewModels into the global widget tree via Provider.
/// 4. Mounts the root [MyApp] widget.
void main() async {
  // CRITICAL: Ensures the Flutter engine is fully loaded before executing 
  // asynchronous native calls (like Firebase.initializeApp).
  WidgetsFlutterBinding.ensureInitialized();

  // ---------------------------------------------------------------------------
  // FIREBASE INITIALIZATION
  // ---------------------------------------------------------------------------
  // Explicitly providing FirebaseOptions ensures reliable connections across 
  // Web, Android, and iOS platforms without relying on the auto-generated config.
  await Firebase.initializeApp(
    options: kIsWeb 
      ? const FirebaseOptions(
          apiKey: "API KEY",
          appId: "1:1047563657237:web:f0c57590374f7686acae1c", 
          messagingSenderId: "1047563657237",
          projectId: "what2eat-1469f",
          authDomain: "what2eat-1469f.firebaseapp.com",
          storageBucket: "what2eat-1469f.firebasestorage.app",
          measurementId: "G-26RF0BNRWF",
          databaseURL: "https://what2eat-1469f-default-rtdb.asia-southeast1.firebasedatabase.app/",
        )
      : const FirebaseOptions(
          apiKey: "API KEY",
          appId: "1:1047563657237:android:be7b031c6999395bacae1c", 
          messagingSenderId: "1047563657237",
          projectId: "what2eat-1469f",
          storageBucket: "what2eat-1469f.firebasestorage.app",
          databaseURL: "https://what2eat-1469f-default-rtdb.asia-southeast1.firebasedatabase.app/",
        ),
  );

  runApp(
    // MultiProvider acts as a dependency injection container.
    // By placing it at the root, these ViewModels survive page navigations
    // and can be accessed anywhere using `context.read<T>()` or `context.watch<T>()`.
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LoginViewModel()),
        ChangeNotifierProvider(create: (_) => VerifyEmailViewModel()),
        ChangeNotifierProvider(create: (_) => RegisterViewModel()),
        ChangeNotifierProvider(create: (_) => HomeViewModel()),
        ChangeNotifierProvider(create: (_) => RoomViewModel()),
        ChangeNotifierProvider(create: (_) => SettingsViewModel()),
        // UNCOMMENTED: Password Reset State Management
        ChangeNotifierProvider(create: (_) => ResetPasswordViewModel()),
      ],
      child: const MyApp(),
    ),
  );
}

/// The root application widget that configures the material theme and routing.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'What2Eat',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF7043)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      ),
      // Starts the user at the Login screen
      initialRoute: '/login',
      // Pulls the central routing table from app.dart
      routes: AppRoutes.routes,
    );
  }
}