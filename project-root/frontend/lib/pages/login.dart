// login.dart is used as the login screen for users
// Users are able to toggle between login and register page

// login.dart is used as the login screen for users
// Users are able to toggle between login and register page, and reset password.

import 'package:flutter/material.dart';
import '../widgets/common_widgets.dart';
import 'register.dart';
import 'forgot_password.dart'; // Ensure you have created this file from the previous step

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // 1. Form Key for validation
  final _formKey = GlobalKey<FormState>();

  // 2. Controllers to capture text input
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    // Clean up controllers to free memory
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        // SingleChildScrollView prevents overflow when keyboard pops up
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: AuthBox(
            // Wrap the column in a Form to enable validation
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Login",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // --- Email Field ---
                  AuthTextField(
                    labelText: "Email",
                    obscureText: false,
                    controller: _emailController,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      // Optional: strict email format check
                      // if (!value.contains('@')) return 'Invalid email format';
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  
                  // --- Password Field ---
                  AuthTextField(
                    labelText: "Password",
                    obscureText: true,
                    controller: _passwordController,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                  ),

                  // --- Forgot Password Link ---
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ForgotPasswordPage(),
                          ),
                        );
                      },
                      child: const Text(
                        "Forgot Password?",
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),
                  
                  // --- Login Button ---
                  AuthButton(
                    text: "Login",
                    onPressed: () {
                      // Trigger Validation
                      if (_formKey.currentState!.validate()) {
                        // 1. Show Feedback
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Logging in...'),
                            backgroundColor: Colors.green,
                            duration: Duration(seconds: 1),
                          ),
                        );

                        // 2. Simulate Network Request & Redirect
                        Future.delayed(const Duration(seconds: 1), () {
                          if (context.mounted) {
                            // Use pushReplacementNamed so they can't go "back" to login
                            Navigator.pushReplacementNamed(context, '/home');
                          }
                        });
                      } else {
                        // Validation Failed
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter valid credentials'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                  ),

                  const SizedBox(height: 10),

                  // --- Register Toggle ---
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
        ),
      ),
    );
  }
}