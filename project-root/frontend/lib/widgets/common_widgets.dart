import 'package:flutter/material.dart';

class AuthBox extends StatelessWidget {
  final Widget child;
  const AuthBox({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 350,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: child,
    );
  }
}

class AuthTextField extends StatelessWidget {
  final String labelText;
  final bool obscureText;
  final TextEditingController? controller;
  // Add this: A function that returns an error string or null
  final String? Function(String?)? validator;

  const AuthTextField({
    super.key,
    required this.labelText,
    required this.obscureText,
    this.controller,
    this.validator, // Add this to constructor
  });

  @override
  Widget build(BuildContext context) {
    // Change TextField to TextFormField to enable validation
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator, // Pass the validator here
      autovalidateMode: AutovalidateMode.onUserInteraction, // Checks as user types
      decoration: InputDecoration(
        labelText: labelText,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class AuthButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const AuthButton({super.key, required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black, // button black
          foregroundColor: Colors.white, // text white
        ),
        onPressed: onPressed,
        child: Text(text),
      ),
    );
  }
}