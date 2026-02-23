// No longer implemented
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'common_widgets.dart'; 
// import '../viewmodels/reset_password_vm.dart';

// /// The Password Reset Screen.
// ///
// /// Allows users to enter their email to receive a password recovery link.
// class ResetPasswordPage extends StatefulWidget {
//   const ResetPasswordPage({super.key});

//   @override
//   State<ResetPasswordPage> createState() => _ResetPasswordPageState();
// }

// class _ResetPasswordPageState extends State<ResetPasswordPage> {
//   final TextEditingController _emailController = TextEditingController();
//   final _formKey = GlobalKey<FormState>();

//   @override
//   void dispose() {
//     _emailController.dispose();
//     super.dispose();
//   }

//   /// Handles the submit action.
//   void _handleSubmit() async {
//     if (_formKey.currentState!.validate()) {
//       final vm = context.read<ResetPasswordViewModel>();
      
//       // Call ViewModel
//       await vm.resetPassword(_emailController.text);

//       // Check for success after the await completes
//       if (vm.isSuccess && mounted) {
//         _showSuccessDialog();
//       }
//     }
//   }

//   /// Displays a success message and navigates back to Login on close.
//   void _showSuccessDialog() {
//     showDialog(
//       context: context,
//       barrierDismissible: false, // User must tap OK
//       builder: (ctx) => AlertDialog(
//         title: const Text("Email Sent"),
//         content: Text("We have sent a password recovery link to ${_emailController.text}. Please check your inbox."),
//         actions: [
//           TextButton(
//             onPressed: () {
//               Navigator.pop(ctx); // Close Dialog
//               Navigator.pop(context); // Go back to Login Page
//             },
//             child: const Text("Back to Login"),
//           )
//         ],
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final vm = context.watch<ResetPasswordViewModel>();

//     return Scaffold(
//       // Standard Back Button in AppBar
//       appBar: AppBar(
//         leading: const BackButton(color: Colors.black),
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(25),
//         child: Column(
//           children: [
//             const AuthHeader(
//               title: "Forgot Password?",
//               subtitle: "Enter your email to reset your password.",
//             ),

//             AuthBox(
//               child: Form(
//                 key: _formKey,
//                 child: Column(
//                   children: [
//                     const Text(
//                       "Don't worry! It happens. Please enter the email associated with your account.",
//                       textAlign: TextAlign.center,
//                       style: TextStyle(color: Colors.grey),
//                     ),
//                     const SizedBox(height: 20),

//                     // Email Input
//                     AuthTextField(
//                       labelText: "Email Address",
//                       obscureText: false,
//                       controller: _emailController,
//                       prefixIcon: const Icon(Icons.email_outlined),
//                       validator: (val) => !val!.contains('@') ? "Invalid email" : null,
//                     ),

//                     const SizedBox(height: 10),

//                     // Error Message Display
//                     if (vm.errorMessage != null)
//                       Padding(
//                         padding: const EdgeInsets.only(bottom: 10),
//                         child: Text(
//                           vm.errorMessage!, 
//                           style: const TextStyle(color: Colors.red),
//                           textAlign: TextAlign.center,
//                         ),
//                       ),

//                     // Submit Button
//                     AuthButton(
//                       text: vm.isLoading ? "Sending..." : "Send Reset Link",
//                       // Disable button if loading to prevent spamming
//                       onPressed: vm.isLoading ? null : _handleSubmit,
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }