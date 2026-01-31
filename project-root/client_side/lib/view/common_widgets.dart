import 'package:flutter/material.dart';

// --- PREMIUM DESIGN CONSTANTS ---

/// The primary brand color (Sunset Orange).
///
/// Used for main buttons, active states, and key highlights.
const Color kPrimaryColor = Color(0xFFFF7043); 

/// The secondary brand color (Deep Orange).
///
/// Used in conjunction with [kPrimaryColor] to create rich gradients.
const Color kSecondaryColor = Color(0xFFFF5722); 

/// The standard background color for screens.
///
/// A very light grey (almost white) used to provide contrast against the
/// pure white containers ([AuthBox]).
const Color kBackgroundColor = Color(0xFFF5F5F5); 

/// The standard border radius used throughout the app.
///
/// Set to 20.0 for a modern, rounded, and friendly aesthetic.
const double kRadius = 20.0; 

// --- 1. The Header Widget (New!) ---

/// A standardized header widget for authentication and major flow screens.
///
/// This widget displays a large, bold title followed by a subtle subtitle.
/// It is designed to be placed at the very top of screens like Login, Register,
/// or Create Room to provide context to the user.
///
/// Usage:
/// ```dart
/// AuthHeader(
///   title: "Welcome Back",
///   subtitle: "Sign in to continue",
/// )
/// ```
class AuthHeader extends StatelessWidget {
  /// The main headline text (e.g., "Sign Up").
  final String title;

  /// The supporting text displayed below the title (e.g., "Join us today").
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

/// A customized text input field with a premium look and feel.
///
/// This widget wraps a [TextFormField] in a container with a subtle shadow
/// and custom border styling. It is designed to "pop" against the 
/// [kBackgroundColor].
///
/// Key Features:
/// * **Shadow Depth:** Floating effect using `BoxShadow`.
/// * **Theming:** automatically uses [kPrimaryColor] for the cursor and icons.
/// * **Validation:** Supports standard [validator] functions.
class AuthTextField extends StatelessWidget {
  /// The label text displayed inside the field (e.g., "Email").
  final String labelText;

  /// Whether the text should be hidden (for passwords).
  final bool obscureText;

  /// The controller to manage the text being edited.
  final TextEditingController controller;

  /// An optional function to validate the input. Returns an error string or null.
  final String? Function(String?)? validator;

  /// Focus node for managing focus state manually.
  final FocusNode? focusNode;

  /// Whether the field is read-only (useful for profile views).
  final bool readOnly;

  /// An optional icon to display at the end of the field.
  final Widget? suffixIcon;

  /// An optional icon to display at the start of the field.
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

/// A primary action button with a vibrant gradient background.
///
/// This button is used for the main calls to action (e.g., "Log In", "Create Room").
/// It features a gradient from [kPrimaryColor] to [kSecondaryColor] and a 
/// drop shadow to make it stand out.
class AuthButton extends StatelessWidget {
  /// The text displayed on the button.
  final String text;

  /// The callback function executed when the button is tapped.
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

/// A generic container styled like a "Card" or "Box".
///
/// This widget provides a white background with rounded corners and a shadow.
/// It is typically used to group form elements (like inputs and buttons) 
/// together, separating them visually from the background.
class AuthBox extends StatelessWidget {
  /// The widget subtree to be displayed inside the box.
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