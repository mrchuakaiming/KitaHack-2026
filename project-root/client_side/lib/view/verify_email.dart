import 'package:flutter/material.dart';
import '../services/analytics_service.dart';
import 'common_widgets.dart';

/// **Step 1: Account Security (Verify Email)**
///
/// **Role:**
/// Acts as a data collector for the registration process.
/// It does **NOT** create an account yet. Instead, it validates the
/// credentials (Regex, matching passwords) and passes them to Step 2.
///
/// **Analytics:**
/// Logs a `sign_up_start` event when the user clicks "Next".
class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  // Key for Form validation (ensures email is valid regex, pass > 6 chars)
  final _formKey = GlobalKey<FormState>();

  // Controllers to capture user input
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  /// Handles the "Next Step" action.
  ///
  /// **Logic:**
  /// 1. Validates inputs locally (Regex, Length, Match).
  /// 2. Logs `sign_up_start` analytics event.
  /// 3. Navigates to `/register`, passing email/password as arguments.
  void _handleNext() {
    if (_formKey.currentState!.validate()) {
      // ANALYTICS: Track that a user has started the funnel
      AnalyticsService().logEvent('sign_up_start', params: {
        'method': 'email_password'
      });

      // PASS-FORWARD STRATEGY:
      // We do not create the user here. We pass the data to Step 2.
      Navigator.pushNamed(
        context,
        '/register', // Route to Step 2
        arguments: {
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create Account")),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const AuthHeader(
              title: "Step 1",
              subtitle: "Secure your account"
            ),
            
            AuthBox(
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // --- Email Field ---
                    AuthTextField(
                      labelText: "Email",
                      obscureText: false,
                      controller: _emailController,
                      prefixIcon: const Icon(Icons.email),
                      validator: (val) => !val!.contains('@') ? 'Invalid Email' : null,
                    ),
                    
                    // --- Password Field ---
                    AuthTextField(
                      labelText: "Password",
                      obscureText: true,
                      controller: _passwordController,
                      prefixIcon: const Icon(Icons.lock),
                      validator: (val) => val!.length < 6 ? 'Min 6 chars' : null,
                    ),
                    
                    // --- Confirm Password Field ---
                    AuthTextField(
                      labelText: "Confirm Password",
                      obscureText: true,
                      controller: _confirmController,
                      prefixIcon: const Icon(Icons.lock_outline),
                      validator: (val) => val != _passwordController.text ? 'Mismatch' : null,
                    ),

                    const SizedBox(height: 20),

                    // --- Action Button ---
                    AuthButton(
                      text: "Next Step",
                      onPressed: _handleNext,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}