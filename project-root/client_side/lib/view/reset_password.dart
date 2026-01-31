import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'common_widgets.dart'; 
import '../viewmodels/reset_password_vm.dart';

/// A dedicated screen for handling password resets.
/// 
/// This widget serves a dual purpose:
/// 1. **Input State:** Allows the user to enter their email address.
/// 2. **Success State:** Confirms that the reset email has been sent.
/// 
/// It can be accessed from the [LoginPage] (if the user forgot their password)
/// or the [SettingsPage] (if the user wants to change their password).
class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  // Controller to capture the email input
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch the ViewModel. This triggers a rebuild whenever 
    // loading state, error messages, or success state changes.
    final vm = context.watch<ResetPasswordViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Reset Password"),
        // Custom back button to ensure navigation is intuitive
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(25.0),
        // --- CONDITIONAL UI RENDERING ---
        // If the email was sent successfully, we swap the entire view 
        // to the Success Confirmation. Otherwise, we show the Input Form.
        child: vm.isSuccess 
          ? _buildSuccessView(context) 
          : _buildInputView(context, vm),
      ),
    );
  }

  // --- VIEW 1: Input Form ---
  /// Renders the form allowing the user to input their email.
  Widget _buildInputView(BuildContext context, ResetPasswordViewModel vm) {
    return Column(
      children: [
        // Standard header for consistency
        const AuthHeader(
          title: "Reset Password", 
          subtitle: "Enter your email to receive a password reset link."
        ),
        
        // AuthBox container for the form fields
        AuthBox(
          child: Column(
            children: [
              // Email Input Field
              AuthTextField(
                labelText: "Email Address",
                obscureText: false,
                controller: _emailController,
                prefixIcon: const Icon(Icons.email_outlined),
              ),
              const SizedBox(height: 20),

              // Error Message Display
              // Only renders if the ViewModel catches an error (e.g., "User not found")
              if (vm.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(vm.errorMessage!, style: const TextStyle(color: Colors.red)),
                ),

              // Submit Button
              // Triggers the verifyEmail function in the ViewModel
              AuthButton(
                text: vm.isLoading ? "Sending..." : "Send Link",
                onPressed: () => vm.verifyEmail(_emailController.text),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- VIEW 2: Success Confirmation ---
  /// Renders the success message after the email has been sent.
  Widget _buildSuccessView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Large Success Icon
          const Icon(Icons.mark_email_read, size: 80, color: Colors.green),
          const SizedBox(height: 20),
          
          // Confirmation Text
          const Text("Email Sent!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(
            "We sent a link to ${_emailController.text}.\nCheck your inbox to reset your password.",
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
          
          const SizedBox(height: 40),
          
          // "Done" Button
          // Pops the current route to return the user to the previous screen (Login or Settings)
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text("Done", style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}