// register.dart is used to register new users 
// Users are able to toggle between login and register page

import 'package:flutter/material.dart';
import '../widgets/common_widgets.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  // Dynamic Lists
  final List<TextEditingController> _cuisineControllers = [];
  final List<TextEditingController> _dietaryControllers = [];

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    for (var c in _cuisineControllers) {
      c.dispose();
    }
    for (var c in _dietaryControllers) {
      c.dispose();
    }
    super.dispose();
  }

  // --- Dynamic Field Logic ---
  void _addCuisine() {
    setState(() {
      _cuisineControllers.add(TextEditingController());
    });
  }

  void _removeCuisine(int index) {
    setState(() {
      _cuisineControllers[index].dispose();
      _cuisineControllers.removeAt(index);
    });
  }

  void _addDietary() {
    setState(() {
      _dietaryControllers.add(TextEditingController());
    });
  }

  void _removeDietary(int index) {
    setState(() {
      _dietaryControllers[index].dispose();
      _dietaryControllers.removeAt(index);
    });
  }
  // ---------------------------

  void _handleRegister() {
    if (_formKey.currentState!.validate()) {
      // Simulate registration
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account Created! Please Login.')),
      );
      Navigator.pop(context); // Return to Login
    }
  }

  // Helper for Section Headers inside the form
  Widget _buildSectionTitle(String title, VoidCallback onAdd) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        IconButton(
          onPressed: onAdd,
          icon: const Icon(Icons.add_circle, color: kPrimaryColor),
          tooltip: "Add $title",
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(25, 0, 25, 25),
        child: Column(
          children: [
            // Header
            const AuthHeader(
              title: "Create Account",
              subtitle: "Join us and decide what to eat.",
            ),

            AuthBox(
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // --- Personal Info ---
                    AuthTextField(
                      labelText: "Username",
                      obscureText: false,
                      controller: _usernameController,
                      prefixIcon: const Icon(Icons.person_outline),
                      validator: (val) => val!.isEmpty ? 'Required' : null,
                    ),
                    AuthTextField(
                      labelText: "Email",
                      obscureText: false,
                      controller: _emailController,
                      prefixIcon: const Icon(Icons.email_outlined),
                      validator: (val) => !val!.contains('@') ? 'Invalid Email' : null,
                    ),
                    AuthTextField(
                      labelText: "Password",
                      obscureText: true,
                      controller: _passwordController,
                      prefixIcon: const Icon(Icons.lock_outline),
                      validator: (val) => val!.length < 6 ? 'Min 6 chars' : null,
                    ),
                    AuthTextField(
                      labelText: "Confirm Password",
                      obscureText: true,
                      controller: _confirmPasswordController,
                      // FIXED: Changed to valid icon 'Icons.lock'
                      prefixIcon: const Icon(Icons.lock), 
                      validator: (val) => val != _passwordController.text ? 'Mismatch' : null,
                    ),

                    const SizedBox(height: 10),
                    const Divider(),
                    const SizedBox(height: 10),

                    // --- Preferences ---
                    _buildSectionTitle("Preferred Cuisines", _addCuisine),
                    
                    ..._cuisineControllers.asMap().entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: AuthTextField(
                                labelText: "Cuisine ${entry.key + 1}",
                                obscureText: false,
                                controller: entry.value,
                              ),
                            ),
                            const SizedBox(width: 5),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _removeCuisine(entry.key),
                            ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 10),

                    _buildSectionTitle("Dietary Restrictions", _addDietary),
                    ..._dietaryControllers.asMap().entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: AuthTextField(
                                labelText: "Restriction ${entry.key + 1}",
                                obscureText: false,
                                controller: entry.value,
                              ),
                            ),
                            const SizedBox(width: 5),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _removeDietary(entry.key),
                            ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 20),

                    // --- Sign Up Button ---
                    AuthButton(
                      text: "Sign Up",
                      onPressed: _handleRegister,
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