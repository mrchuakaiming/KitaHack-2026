import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'common_widgets.dart'; 
import '../viewmodels/login_vm.dart';

/// The Entry Point of the Application.
///
/// This widget provides the Email/Password login form.
/// It uses [LoginViewModel] to handle the authentication state.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Key for validating the form fields
  final _formKey = GlobalKey<FormState>();
  
  // Controllers for text input
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Triggers the Login Logic.
  ///
  /// 1. Validates the form format (email regex, password length).
  /// 2. Calls [LoginViewModel.logIn].
  /// 3. Navigates to Home on success.
  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      // Access the ViewModel
      final vm = context.read<LoginViewModel>();

      // Execute Login
      bool success = await vm.logIn(
        _emailController.text, 
        _passwordController.text
      );

      // Navigate on Success
      if (success && mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch the ViewModel to rebuild on loading state changes or errors
    final vm = context.watch<LoginViewModel>();

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            const SizedBox(height: 60),
            
            // --- HEADER ---
            const AuthHeader(
              title: "Welcome Back to What2Eat",
              subtitle: "Sign in",
            ),

            // --- FORM BOX ---
            AuthBox(
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Email Input
                    AuthTextField(
                      labelText: "Email",
                      obscureText: false,
                      controller: _emailController,
                      prefixIcon: const Icon(Icons.email_outlined),
                      validator: (val) => !val!.contains('@') ? 'Invalid Email' : null,
                    ),
                    
                    // Password Input
                    AuthTextField(
                      labelText: "Password",
                      obscureText: true,
                      controller: _passwordController,
                      prefixIcon: const Icon(Icons.lock_outline),
                      validator: (val) => val!.isEmpty ? 'Password required' : null,
                    ),

                    // Forgot Password Link
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/reset_password'),
                        child: const Text("Forgot Password?", style: TextStyle(color: Colors.grey)),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Error Display
                    if (vm.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          vm.errorMessage!, 
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    // Login Button
                    AuthButton(
                      text: vm.isLoading ? "Signing In..." : "Log In",
                      // Disable button while loading to prevent double-taps
                      onPressed: vm.isLoading ? null : () => _handleLogin(),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            // --- CREATE ACCOUNT LINK ---
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("New here? ", style: TextStyle(color: Colors.grey)),
                GestureDetector(
                  // UPDATED: Points to the new Step 1 (Verify Email) page
                  onTap: () => Navigator.pushNamed(context, '/verify_email'),
                  child: const Text(
                    "Create Account", 
                    style: TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}