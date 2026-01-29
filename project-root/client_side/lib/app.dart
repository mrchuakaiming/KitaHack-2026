import 'package:flutter/material.dart';
import 'pages/login.dart';
import 'pages/register.dart';
import 'pages/home_page.dart';
import 'pages/create_rooms.dart';
import 'pages/room.dart';
import 'pages/settings_page.dart';
import 'pages/change_password.dart';
import 'pages/forgot_password.dart';

class AppRoutes {
  static Map<String, Widget Function(BuildContext)> routes = {
    '/login': (context) => const LoginPage(),
    '/register': (context) => const RegisterPage(),
    '/home': (context) => const HomePage(),
    '/create_room': (context) => CreateRoomPage(),
    '/room': (context) => const RoomPage(),
    '/settings': (context) => const SettingsPage(),
    '/change_password': (context) => ChangePasswordPage(),
    '/forgot_password': (context) => ForgotPasswordPage(),
  };
}