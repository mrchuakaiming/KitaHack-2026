import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'common_widgets.dart'; 
import '../viewmodels/change_password_vm.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ChangePasswordViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Change Password"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const AuthHeader(
              title: "Update Credentials", 
              subtitle: "Make sure your new password is secure."
            ),
            
            AuthBox(
              child: Column(
                children: [
                  AuthTextField(
                    labelText: "Current Password",
                    obscureText: true,
                    controller: _currentController,
                    prefixIcon: const Icon(Icons.lock_outline),
                  ),
                  const SizedBox(height: 10),
                  AuthTextField(
                    labelText: "New Password",
                    obscureText: true,
                    controller: _newController,
                    prefixIcon: const Icon(Icons.lock),
                  ),
                  AuthTextField(
                    labelText: "Confirm New Password",
                    obscureText: true,
                    controller: _confirmController,
                    prefixIcon: const Icon(Icons.lock_clock),
                  ),
                  
                  const SizedBox(height: 20),

                  if (vm.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        vm.errorMessage!, 
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  AuthButton(
                    text: vm.isLoading ? "Updating..." : "Update Password",
                    onPressed: () async {
                      // CALLING resetPassword()
                      bool success = await vm.resetPassword(
                        currentPassword: _currentController.text,
                        newPassword: _newController.text,
                        confirmPassword: _confirmController.text,
                      );

                      if (success && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Password updated successfully!")),
                        );
                        Navigator.pop(context);
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}