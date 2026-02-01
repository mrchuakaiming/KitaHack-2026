import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'common_widgets.dart'; 
import '../viewmodels/register_vm.dart';

/// The Registration Screen.
///
/// Collects all necessary information to create a new user account:
/// 1. Credentials (Email/Password)
/// 2. Profile Info (Username, Cuisines, Dietary Restrictions)
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  
  // -- Controllers for Credentials --
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  
  // -- Controllers for Profile --
  final TextEditingController _usernameController = TextEditingController();
  
  // -- Dynamic Lists --
  final List<TextEditingController> _cuisineControllers = [];
  final List<TextEditingController> _dietaryControllers = [];

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _usernameController.dispose();
    for (var c in _cuisineControllers) c.dispose();
    for (var c in _dietaryControllers) c.dispose();
    super.dispose();
  }

  // --- DYNAMIC FIELDS LOGIC ---
  void _addCuisine() => setState(() => _cuisineControllers.add(TextEditingController()));
  void _removeCuisine(int index) => setState(() {
    _cuisineControllers[index].dispose();
    _cuisineControllers.removeAt(index);
  });

  void _addDietary() => setState(() => _dietaryControllers.add(TextEditingController()));
  void _removeDietary(int index) => setState(() {
    _dietaryControllers[index].dispose();
    _dietaryControllers.removeAt(index);
  });

  // --- SUBMISSION LOGIC ---
  void _handleRegister() async {
    if (_formKey.currentState!.validate()) {
      final vm = context.read<RegisterViewModel>();

      // Extract Strings from Dynamic Controllers
      final cuisines = _cuisineControllers.map((c) => c.text).where((t) => t.isNotEmpty).toList();
      final dietary = _dietaryControllers.map((c) => c.text).where((t) => t.isNotEmpty).toList();

      // Call the Master Flow
      bool success = await vm.registerUser(
        email: _emailController.text,
        password: _passwordController.text,
        username: _usernameController.text,
        cuisines: cuisines,
        dietary: dietary,
      );

      if (success && mounted) {
        // Navigate to Home upon successful registration & auto-login
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RegisterViewModel>();

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(color: Colors.black),
        backgroundColor: Colors.transparent, 
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(25, 0, 25, 25),
        child: Column(
          children: [
            const AuthHeader(
              title: "Create Account",
              subtitle: "Join us to find your next meal.",
            ),

            AuthBox(
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // --- CREDENTIALS SECTION ---
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
                      controller: _confirmController,
                      prefixIcon: const Icon(Icons.lock),
                      validator: (val) => val != _passwordController.text ? 'Mismatch' : null,
                    ),
                    
                    const Divider(height: 30),

                    // --- PROFILE SECTION ---
                    AuthTextField(
                      labelText: "Username",
                      obscureText: false,
                      controller: _usernameController,
                      prefixIcon: const Icon(Icons.person_outline),
                      validator: (val) => val!.isEmpty ? 'Required' : null,
                    ),

                    const SizedBox(height: 10),
                    
                    // Cuisines
                    _buildSectionTitle("Favorite Cuisines", _addCuisine),
                    ..._cuisineControllers.asMap().entries.map((e) => _buildDynamicRow(e, _removeCuisine)),

                    const SizedBox(height: 10),

                    // Dietary
                    _buildSectionTitle("Dietary Restrictions", _addDietary),
                    ..._dietaryControllers.asMap().entries.map((e) => _buildDynamicRow(e, _removeDietary)),

                    const SizedBox(height: 20),

                    // Error & Submit
                    if (vm.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(vm.errorMessage!, style: const TextStyle(color: Colors.red)),
                      ),

                    AuthButton(
                      text: vm.isLoading ? "Creating Account..." : "Register",
                      onPressed: vm.isLoading ? null : _handleRegister,
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

  // --- UI HELPERS ---

  Widget _buildSectionTitle(String title, VoidCallback onAdd) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        IconButton(
          onPressed: onAdd,
          icon: const Icon(Icons.add_circle, color: kPrimaryColor),
          tooltip: "Add Item",
        ),
      ],
    );
  }

  Widget _buildDynamicRow(MapEntry<int, TextEditingController> entry, Function(int) onRemove) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Expanded(child: AuthTextField(labelText: "Item ${entry.key + 1}", obscureText: false, controller: entry.value)),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => onRemove(entry.key),
          )
        ],
      ),
    );
  }
}