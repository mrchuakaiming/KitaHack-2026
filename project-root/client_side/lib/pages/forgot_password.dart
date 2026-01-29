import 'package:flutter/material.dart';
import '../widgets/common_widgets.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: AuthBox(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Reset Password",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Enter your email to receive a password reset link.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  
                  // Email Field
                  AuthTextField(
                    labelText: "Email",
                    obscureText: false,
                    controller: _emailController,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please enter your email';
                      if (!value.contains('@')) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  
                  // Reset Button
                  AuthButton(
                    text: "Send Reset Link",
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        // Simulate sending email
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Reset link sent to ${_emailController.text}'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        // Optional: Navigate back to login after delay
                        // Future.delayed(const Duration(seconds: 2), () => Navigator.pop(context));
                      }
                    },
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