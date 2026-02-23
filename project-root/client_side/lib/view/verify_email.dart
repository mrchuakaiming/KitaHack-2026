import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/analytics_service.dart';
import 'common_widgets.dart';
import '../viewmodels/verify_email_vm.dart';

/// ==============================================================================
/// STEP 1: ACCOUNT SECURITY (VERIFY EMAIL)
/// ==============================================================================
/// **Role:**
/// The entry point for the sign-up flow. This page collects the user's
/// primary credentials (email and password). It defers all validation to the 
/// ViewModel and passes the valid data to Step 2 via navigation arguments.
class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  // Global key for potential future Form widget expansion
  final _formKey = GlobalKey<FormState>();

  // Input Controllers for tracking user text
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  /// --------------------------------------------------------------------------
  /// LIFECYCLE
  /// --------------------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    // Real-time listener for the password length requirement.
    // Every keystroke triggers the ViewModel to update the UI indicator.
    _passwordController.addListener(() {
      context.read<VerifyEmailViewModel>().updatePasswordStatus(_passwordController.text);
    });
  }

  @override
  void dispose() {
    // Prevent memory leaks by disposing controllers when navigating away
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  /// --------------------------------------------------------------------------
  /// ACTIONS
  /// --------------------------------------------------------------------------
  
  /// Handles the "Next Step" action by calling the validation gatekeeper in the VM.
  void _handleNext(VerifyEmailViewModel vm) {
    debugPrint("UI: Next Step Button Pressed");

    // Pass the raw text to the ViewModel for strict validation
    final isValid = vm.validateInput(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      confirmPassword: _confirmController.text,
    );

    // Only proceed if the ViewModel guarantees the data is secure and properly formatted
    if (isValid) {
      debugPrint("UI: Validation Passed. Navigating to /register...");
      
      // Log Analytics Event to track funnel progression
      AnalyticsService().logEvent('sign_up_start', params: {
        'method': 'email_password',
      });

      // Navigate to Step 2 (RegisterPage) and pass the validated credentials
      // Note: We intentionally do NOT trim the password here, so Firebase receives
      // exactly what the user typed (even if they appended spaces to a valid password).
      Navigator.pushNamed(
        context,
        '/register',
        arguments: {
          'email': _emailController.text.trim(),
          'password': _passwordController.text, 
        },
      );
    } else {
      debugPrint("UI: Validation Failed.");
    }
  }

  /// Routes the user back to the Login screen if they already have an account.
  void _handleBackToLogin() {
    Navigator.pushReplacementNamed(context, '/login');
  }

  /// --------------------------------------------------------------------------
  /// BUILD
  /// --------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    // Watch the ViewModel to react to error messages and checklist updates
    final vm = context.watch<VerifyEmailViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text("Create Account")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 30),
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
                    // Email Field
                    AuthTextField(
                      labelText: "Email",
                      obscureText: false,
                      controller: _emailController,
                      prefixIcon: const Icon(Icons.email),
                    ),
                    
                    // Password Field
                    AuthTextField(
                      labelText: "Password",
                      obscureText: true,
                      controller: _passwordController,
                      prefixIcon: const Icon(Icons.lock),
                    ),
                    
                    // Confirm Password Field
                    AuthTextField(
                      labelText: "Confirm Password",
                      obscureText: true,
                      controller: _confirmController,
                      prefixIcon: const Icon(Icons.lock_outline),
                    ),

                    const SizedBox(height: 15),

                    // --- VISUAL PASSWORD REQUIREMENT ---
                    // Reacts in real-time to the length of the string
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: _PasswordRequirementIndicator(isMet: vm.hasMinLength),
                    ),

                    const SizedBox(height: 25),

                    // --- ERROR MESSAGE DISPLAY ---
                    // Shows the specific validation failure reason (e.g. "Passwords do not match")
                    if (vm.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          vm.errorMessage!, 
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    // Primary Action Button
                    AuthButton(
                      text: "Next Step",
                      onPressed: () => _handleNext(vm),
                    ),

                    const SizedBox(height: 20),
                    
                    // Footer Navigation
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Already have an account?", style: TextStyle(color: Colors.grey)),
                        TextButton(
                          onPressed: _handleBackToLogin,
                          child: const Text("Login", style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
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

/// ==============================================================================
/// PASSWORD REQUIREMENT INDICATOR
/// ==============================================================================
/// A simplified UI widget to visually confirm the 6-character length status.
class _PasswordRequirementIndicator extends StatelessWidget {
  /// Dictates whether to show the active green state or the inactive grey state.
  final bool isMet;
  
  const _PasswordRequirementIndicator({required this.isMet});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMet ? Colors.green.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.circle_outlined, 
            size: 18, 
            color: isMet ? Colors.green : Colors.grey
          ),
          const SizedBox(width: 10),
          Text(
            "Minimum 6 characters",
            style: TextStyle(
              fontSize: 13, 
              color: isMet ? Colors.green[800] : Colors.grey[700],
              fontWeight: isMet ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}