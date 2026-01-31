// login.dart is used as the login screen for users
// Users are able to toggle between login and register page

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'common_widgets.dart'; // Same folder
import '../viewmodels/login_vm.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch the VM to update UI when loading/error changes
    final viewModel = context.watch<LoginViewModel>();

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(25.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Header
                const Icon(Icons.restaurant_menu, size: 80, color: Color(0xFFFF7043)),
                const SizedBox(height: 20),
                const Text("What2Eat", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const Text("Decide your next meal together.", style: TextStyle(fontSize: 16, color: Colors.grey)),
                
                const SizedBox(height: 40),

                // Form
                AuthBox(
                  child: Column(
                    children: [
                      AuthTextField(
                        labelText: "Email", 
                        obscureText: false, 
                        controller: _emailController,
                        prefixIcon: const Icon(Icons.email_outlined),
                      ),
                      AuthTextField(
                        labelText: "Password", 
                        obscureText: true, 
                        controller: _passwordController,
                        prefixIcon: const Icon(Icons.lock_outline),
                      ),
                      
                      const SizedBox(height: 10),

                      // Forgot Password Link
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.pushNamed(context, '/forgot_password'),
                          child: const Text("Forgot Password?", style: TextStyle(color: Colors.grey)),
                        ),
                      ),

                      // Error Message Display
                      if (viewModel.errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(viewModel.errorMessage!, style: const TextStyle(color: Colors.red)),
                        ),

                      // Login Button
                      AuthButton(
                        text: viewModel.isLoading ? "Logging in..." : "Log In",
                        onPressed: () async {
                          // 1. Call VM
                          bool success = await viewModel.logIn(
                            _emailController.text, 
                            _passwordController.text
                          );
                          
                          // 2. Navigate on Success
                          if (success && mounted) {
                            Navigator.pushReplacementNamed(context, '/home');
                          }
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Register Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("New here? ", style: TextStyle(color: Colors.grey)),
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/register'),
                      child: const Text("Create Account", style: TextStyle(color: Color(0xFFFF7043), fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}