import 'package:flutter/material.dart';
import 'pages/login.dart';
import 'pages/register.dart';
import 'pages/forgot_password.dart';
import 'pages/home_page.dart';
import 'pages/create_rooms.dart';
import 'pages/settings_page.dart';
import 'pages/change_password.dart';
import 'pages/join_room.dart';

class AppRoutes {
  static Map<String, Widget Function(BuildContext)> routes = {
    '/login': (context) => const LoginPage(),
    '/register': (context) => const RegisterPage(),
    '/forgot_password': (context) => const ForgotPasswordPage(),
    '/home': (context) => const HomePage(),
    '/create_room': (context) => const CreateRoomPage(),
    '/settings': (context) => const SettingsPage(),
    '/change_password': (context) => const ChangePasswordPage(),
    '/join_room': (context) => const JoinRoomPage(),
  };
}