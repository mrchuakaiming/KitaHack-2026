import 'package:flutter/material.dart';

// Correct Imports for your structure
import 'view/login.dart';
import 'view/register.dart';
import 'view/home_page.dart';
import 'view/room.dart';
import 'view/settings_page.dart';
import 'view/change_password.dart';
import 'view/forgot_password.dart';

class AppRoutes {
  static Map<String, Widget Function(BuildContext)> routes = {
    '/login': (context) => const LoginPage(),
    '/register': (context) => const RegisterPage(),
    '/home': (context) => const HomePage(),
    '/room': (context) => const RoomPage(),
    '/settings': (context) => const SettingsPage(),
    '/change_password': (context) => ChangePasswordPage(),
    '/forgot_password': (context) => ForgotPasswordPage(),
  };
}