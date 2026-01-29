import 'package:flutter/material.dart';

// --- PREMIUM DESIGN CONSTANTS ---
const Color kPrimaryColor = Color(0xFFFF7043); // Sunset Orange
const Color kSecondaryColor = Color(0xFFFF5722); // Deep Orange (for gradient)
const Color kBackgroundColor = Color(0xFFF5F5F5); 
const double kRadius = 20.0; // Smoother, larger curves

// --- 1. The Header Widget (New!) ---
// Use this at the top of Login, Register, Create Room, etc.
class AuthHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const AuthHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800, // Extra Bold
            color: Colors.black87,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade600,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }
}

// --- 2. The Input Field (Refined) ---
class AuthTextField extends StatelessWidget {
  final String labelText;
  final bool obscureText;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final FocusNode? focusNode;
  final bool readOnly;
  final Widget? suffixIcon;
  final Widget? prefixIcon;

  const AuthTextField({
    super.key,
    required this.labelText,
    required this.obscureText,
    required this.controller,
    this.validator,
    this.focusNode,
    this.readOnly = false,
    this.suffixIcon,
    this.prefixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20), // consistent spacing
      decoration: BoxDecoration(
        boxShadow: [
          // Very subtle shadow for depth
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        validator: validator,
        focusNode: focusNode,
        readOnly: readOnly,
        style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.normal),
          
          filled: true,
          fillColor: Colors.white, // Pure white background pops against grey pages
          
          prefixIcon: prefixIcon != null 
              ? IconTheme(data: IconThemeData(color: kPrimaryColor), child: prefixIcon!) 
              : null,
          suffixIcon: suffixIcon,
          
          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
          
          // Borders
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(kRadius),
            borderSide: BorderSide(color: Colors.grey.shade200), // Subtle border
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(kRadius),
            borderSide: const BorderSide(color: kPrimaryColor, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(kRadius),
            borderSide: const BorderSide(color: Colors.red, width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(kRadius),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
        ),
      ),
    );
  }
}

// --- 3. The Gradient Button (The Star Show) ---
class AuthButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const AuthButton({
    super.key,
    required this.text,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 60, // Large touch target
      decoration: BoxDecoration(
        // THE GRADIENT: Makes it look "Tasty" and Premium
        gradient: const LinearGradient(
          colors: [kPrimaryColor, kSecondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(kRadius),
        boxShadow: [
          BoxShadow(
            color: kPrimaryColor.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent, // Transparent so gradient shows
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

// --- 4. The Card Container ---
class AuthBox extends StatelessWidget {
  final Widget child;

  const AuthBox({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30), // Spacious padding
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}