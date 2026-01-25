// register.dart is used to register new users 
// Users are able to toggle between login and register page

import 'package:flutter/material.dart';
import '../widgets/common_widgets.dart';
import 'login.dart';

class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

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
                "Register", // header
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 20),
              const AuthTextField(
                labelText: "Name",
                obscureText: false,
              ),
              const SizedBox(height: 10),
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
                text: "Register",
                onPressed: () {
                  // handle register
                },
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginPage(),
                    ),
                  );
                },
                child: const Text(
                  "Already have an account? Login",
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




