import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'common_widgets.dart'; 
import '../viewmodels/forgot_password_vm.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ForgotPasswordViewModel>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(25.0),
        child: vm.isVerified 
        ? _buildResultView(context) 
        : _buildVerifyView(context, vm),
      ),
    );
  }

  // View 1: Input
  Widget _buildVerifyView(BuildContext context, ForgotPasswordViewModel vm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.lock_reset, size: 80, color: kPrimaryColor),
        const SizedBox(height: 20),
        const Text("Forgot Password?", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        const Text(
          "Enter your email to receive a link to change your password.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 30),

        AuthBox(
          child: Column(
            children: [
              AuthTextField(
                labelText: "Email Address",
                obscureText: false,
                controller: _emailController,
                prefixIcon: const Icon(Icons.email_outlined),
              ),
              const SizedBox(height: 20),
              
              if (vm.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(vm.errorMessage!, style: const TextStyle(color: Colors.red)),
                ),

              AuthButton(
                text: vm.isLoading ? "Verifying..." : "Verify",
                onPressed: () async {
                  // CALLING verifyEmail()
                  await vm.verifyEmail(_emailController.text);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // View 2: Result
  Widget _buildResultView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.mark_email_read, size: 100, color: Colors.green),
          const SizedBox(height: 20),
          const Text("Link Sent!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          Text(
            "We have sent a Change Password link to:\n${_emailController.text}",
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 40),
          
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade200,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(context), 
              child: const Text("Back to Login", style: TextStyle(color: Colors.black, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}