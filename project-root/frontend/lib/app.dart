import 'package:flutter/material.dart';
import 'pages/login.dart';
import 'pages/register.dart';

class AppRoutes {
  static Map<String, Widget Function(BuildContext)> routes = {
    '/login': (context) => const LoginPage(),
    '/register': (context) => const RegisterPage(),
  };
}
