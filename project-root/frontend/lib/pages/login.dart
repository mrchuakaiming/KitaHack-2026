// login.dart is used as the login screen for users
// Users are able to toggle between login and register page

import 'package:flutter/material.dart';
import '../widgets/common_widgets.dart';
import 'register.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // background white
      body: Center(
        child: AuthBox(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Login", // header
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 20),
              const AuthTextField(
                labelText: "Email",
                obscureText: false,
              ),
              const SizedBox(height: 10),
              const AuthTextField(
                labelText: "Password",
                obscureText: true,
              ),
              const SizedBox(height: 20),
              AuthButton(
                text: "Login",
                onPressed: () {
                  // handle login
                },
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RegisterPage(),
                    ),
                  );
                },
                child: const Text(
                  "Don't have an account? Register",
                  style: TextStyle(color: Colors.black),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
