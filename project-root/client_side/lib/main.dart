import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';

// Import all ViewModels
import 'viewmodels/login_vm.dart';
import 'viewmodels/verify_email_vm.dart'; // NEW
import 'viewmodels/register_vm.dart';
import 'viewmodels/home_vm.dart';
import 'viewmodels/room_vm.dart';
import 'viewmodels/settings_page_vm.dart';
import 'viewmodels/reset_password_vm.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        // 1. Login State
        ChangeNotifierProvider(create: (_) => LoginViewModel()),
        
        // 2. Registration Step 1: Verify Email (Auth Creation) - NEW
        ChangeNotifierProvider(create: (_) => VerifyEmailViewModel()),

        // 3. Registration Step 2: Profile Creation (Firestore)
        ChangeNotifierProvider(create: (_) => RegisterViewModel()),
        
        // 4. Core Features
        ChangeNotifierProvider(create: (_) => HomeViewModel()),
        ChangeNotifierProvider(create: (_) => RoomViewModel()),
        ChangeNotifierProvider(create: (_) => SettingsViewModel()),
        ChangeNotifierProvider(create: (_) => ResetPasswordViewModel()), 
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
      initialRoute: '/login',
      routes: AppRoutes.routes,
    );
  }
}