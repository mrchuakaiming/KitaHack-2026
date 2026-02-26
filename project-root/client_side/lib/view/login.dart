import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'common_widgets.dart'; 
import '../viewmodels/login_vm.dart';

/// ==============================================================================
/// LOGIN PAGE (View)
/// ==============================================================================
/// The entry point for unauthenticated users.
///
/// This widget provides the Email/Password login form and delegates all 
/// authentication logic to the [LoginViewModel]. It listens to state changes
/// to show loading spinners or error messages reactively.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  /// GlobalKey used to trigger form validation natively in Flutter.
  final _formKey = GlobalKey<FormState>();
  
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Handles the execution of the login flow when the user presses "Log In".
  ///
  /// Flow:
  /// 1. Runs local regex validation on the input fields.
  /// 2. Suspends execution while awaiting the [LoginViewModel.logIn] network call.
  /// 3. If successful, reroutes the user to the `/home` dashboard.
  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      final vm = context.read<LoginViewModel>();

      bool success = await vm.logIn(
        _emailController.text, 
        _passwordController.text
      );

      // Ensures the widget is still on screen before navigating
      if (success && mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // context.watch forces the UI to rebuild if isLoading or errorMessage changes.
    final vm = context.watch<LoginViewModel>();

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            const SizedBox(height: 60),
            
            const AuthHeader(
              title: "Welcome Back to What2Eat",
              subtitle: "Sign in",
            ),

            AuthBox(
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    AuthTextField(
                      labelText: "Email",
                      obscureText: false,
                      controller: _emailController,
                      prefixIcon: const Icon(Icons.email_outlined),
                      validator: (val) => !val!.contains('@') ? 'Invalid Email' : null,
                    ),
                    
                    AuthTextField(
                      labelText: "Password",
                      obscureText: true,
                      controller: _passwordController,
                      prefixIcon: const Icon(Icons.lock_outline),
                      validator: (val) => val!.isEmpty ? 'Password required' : null,
                    ),

                    // Forgot Password Navigation
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/reset_password'),
                        child: const Text("Forgot Password?", style: TextStyle(color: Colors.grey)),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Dynamic Error Rendering
                    if (vm.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          vm.errorMessage!, 
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    // Submit Button
                    AuthButton(
                      text: vm.isLoading ? "Signing In..." : "Log In",
                      onPressed: vm.isLoading ? null : () => _handleLogin(),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Navigation to Account Creation
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("New here? ", style: TextStyle(color: Colors.grey)),
                GestureDetector(
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