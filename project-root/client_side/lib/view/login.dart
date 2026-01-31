// login.dart is used as the login screen for users
// Users are able to toggle between login and register page

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'common_widgets.dart';
import '../viewmodels/login_vm.dart';

/// The entry point for unauthenticated users.
///
/// This widget provides the user interface for:
/// 1. **Authentication:** Entering email and password to sign in.
/// 2. **Navigation:** Linking to the Registration page ('/register') and Password Reset ('/reset_password').
/// 3. **Feedback:** displaying error messages from the [LoginViewModel] (e.g., "Wrong password").
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Controllers to capture user input
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  /// Clean up controllers when the widget is removed from the widget tree.
  /// This prevents memory leaks.
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch the VM to update UI when loading/error changes.
    // context.watch() triggers a rebuild whenever LoginViewModel calls notifyListeners().
    final viewModel = context.watch<LoginViewModel>();

    return Scaffold(
      // Padding ensures content doesn't touch the screen edges
      body: Padding(
        padding: const EdgeInsets.all(25.0),
        child: Center(
          // SingleChildScrollView prevents "pixel overflow" errors when the keyboard appears.
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // --- HEADER SECTION ---
                // Displays the App Icon and Welcome Text
                const Icon(Icons.restaurant_menu, size: 80, color: Color(0xFFFF7043)),
                const SizedBox(height: 20),
                const Text("What2Eat", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const Text("Decide your next meal together.", style: TextStyle(fontSize: 16, color: Colors.grey)),
                
                const SizedBox(height: 40),

                // --- FORM SECTION ---
                // Wrapped in AuthBox for consistent styling (white card with shadow)
                AuthBox(
                  child: Column(
                    children: [
                      // Email Input
                      AuthTextField(
                        labelText: "Email", 
                        obscureText: false, 
                        controller: _emailController,
                        prefixIcon: const Icon(Icons.email_outlined),
                      ),
                      // Password Input (obscureText = true hides characters)
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
                          // CHANGED ROUTE HERE
                          // Navigates to the Reset Password screen
                          onPressed: () => Navigator.pushNamed(context, '/reset_password'),
                          child: const Text("Forgot Password?", style: TextStyle(color: Colors.grey)),
                        ),
                      ),

                      // Error Message Display
                      // Only renders if the ViewModel reports an error (e.g., failed login attempt)
                      if (viewModel.errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(viewModel.errorMessage!, style: const TextStyle(color: Colors.red)),
                        ),

                      // Login Button
                      // The text changes to "Logging in..." when async operation is active.
                      AuthButton(
                        text: viewModel.isLoading ? "Logging in..." : "Log In",
                        onPressed: () async {
                          // 1. Call VM to perform authentication
                          bool success = await viewModel.logIn(
                            _emailController.text, 
                            _passwordController.text
                          );
                          
                          // 2. Navigate on Success
                          // If login is successful, replace the current route with Home.
                          // 'mounted' check ensures the widget is still on screen before navigating.
                          if (success && mounted) {
                            Navigator.pushReplacementNamed(context, '/home');
                          }
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // --- FOOTER SECTION ---
                // Link to Registration Page for new users
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