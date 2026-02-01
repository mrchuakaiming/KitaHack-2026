import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'common_widgets.dart';
import '../viewmodels/register_vm.dart';

/// The first step of registration: Account Security.
///
/// **Logic:**
/// Collects Email/Password and calls [RegisterViewModel.verifyEmail].
/// On success, navigates to [RegisterPage].
class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  final _formKey = GlobalKey<FormState>();
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

  void _handleNext() async {
    if (_formKey.currentState!.validate()) {
      final vm = context.read<RegisterViewModel>();

      // EXECUTE VM LOGIC
      bool success = await vm.verifyEmail(
        _emailController.text, 
        _passwordController.text
      );

      if (success && mounted) {
        // Step 1 Complete -> Go to Step 2
        Navigator.pushReplacementNamed(context, '/register');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // We use RegisterViewModel here as well, since it holds the methods for this flow.
    final vm = context.watch<RegisterViewModel>();

    return Scaffold(
      appBar: AppBar(leading: const BackButton(color: Colors.black)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            const AuthHeader(
              title: "Create Account",
              subtitle: "First, secure your login details.",
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
                      prefixIcon: const Icon(Icons.email),
                      validator: (val) => !val!.contains('@') ? 'Invalid Email' : null,
                    ),
                    AuthTextField(
                      labelText: "Password",
                      obscureText: true,
                      controller: _passwordController,
                      prefixIcon: const Icon(Icons.lock),
                      validator: (val) => val!.length < 6 ? 'Min 6 chars' : null,
                    ),
                    AuthTextField(
                      labelText: "Confirm Password",
                      obscureText: true,
                      controller: _confirmController,
                      prefixIcon: const Icon(Icons.lock_outline),
                      validator: (val) => val != _passwordController.text ? 'Mismatch' : null,
                    ),

                    const SizedBox(height: 20),

                    if (vm.errorMessage != null)
                      Text(vm.errorMessage!, style: const TextStyle(color: Colors.red)),

                    AuthButton(
                      text: vm.isLoading ? "Processing..." : "Next Step",
                      onPressed: vm.isLoading ? null : _handleNext,
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