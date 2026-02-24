import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
// Note: We keep these imports to ensure the app knows about the services,
// even if we don't use them directly in main().
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode checks if needed later
import 'app.dart';

// ViewModels
import 'viewmodels/login_vm.dart';
import 'viewmodels/verify_email_vm.dart';
import 'viewmodels/register_vm.dart';
import 'viewmodels/home_vm.dart';
import 'viewmodels/room_vm.dart';
import 'viewmodels/settings_page_vm.dart';
import 'viewmodels/reset_password_vm.dart';

/// The entry point of the application.
///
/// This function is responsible for:
/// 1. Setting up the Flutter engine binding.
/// 2. Initializing the Firebase SDK with specific project credentials.
/// 3. Injecting the necessary State Management providers (ViewModels).
/// 4. Launching the root widget (MyApp).
void main() async {
  // CRITICAL: Ensures the Flutter engine is fully loaded before we try to
  // run any asynchronous code (like Firebase.initializeApp).
  // Without this, the app will crash instantly on startup.
  WidgetsFlutterBinding.ensureInitialized();

  // ---------------------------------------------------------------------------
  // FIREBASE INITIALIZATION
  // ---------------------------------------------------------------------------
  // We are manually providing the FirebaseOptions here because the automatic
  // CLI configuration failed. These keys allow the app to talk to the
  // correct project on Google's servers.
  await Firebase.initializeApp(
    options: kIsWeb 
      ? const FirebaseOptions(
          apiKey: "API KEY",
          appId: "1:1047563657237:web:f0c57590374f7686acae1c", // Your Web ID
          messagingSenderId: "1047563657237",
          projectId: "what2eat-1469f",
          authDomain: "what2eat-1469f.firebaseapp.com",
          storageBucket: "what2eat-1469f.firebasestorage.app",
          measurementId: "G-26RF0BNRWF",
          databaseURL: "https://what2eat-1469f-default-rtdb.asia-southeast1.firebasedatabase.app/",
        )
      : const FirebaseOptions(
          apiKey: "API KEY",
          appId: "1:1047563657237:android:be7b031c6999395bacae1c", // Your Android ID
          messagingSenderId: "1047563657237",
          projectId: "what2eat-1469f",
          storageBucket: "what2eat-1469f.firebasestorage.app",
          databaseURL: "https://what2eat-1469f-default-rtdb.asia-southeast1.firebasedatabase.app/",
        ),
  );

  // ---------------------------------------------------------------------------
  // PRODUCTION MODE
  // ---------------------------------------------------------------------------
  // The Emulator connection code has been REMOVED.
  // The app will now read/write directly to the live Google Cloud servers.
  // Ensure your Firestore and Realtime Database rules are set to "Test Mode"
  // (public) in the console for now so you can write data without login errors.

  runApp(
    // MultiProvider injects the ViewModels into the widget tree so they are
    // accessible from anywhere in the app via context.read/watch.
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LoginViewModel()),
        ChangeNotifierProvider(create: (_) => VerifyEmailViewModel()),
        ChangeNotifierProvider(create: (_) => RegisterViewModel()),
        ChangeNotifierProvider(create: (_) => HomeViewModel()),
        ChangeNotifierProvider(create: (_) => RoomViewModel()),
        ChangeNotifierProvider(create: (_) => SettingsViewModel()),
        // ChangeNotifierProvider(create: (_) => ResetPasswordViewModel()),
      ],
      child: const MyApp(),
    ),
  );
}

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
      // Define the starting route of the app
      initialRoute: '/login',
      // Load routes from the AppRoutes class
      routes: AppRoutes.routes,
    );
  }
}