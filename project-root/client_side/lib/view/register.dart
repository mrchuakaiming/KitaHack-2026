// register.dart is used to register new users 
// Users are able to toggle between login and register page

import 'package:flutter/material.dart';
import 'common_widgets.dart';

/// The screen responsible for new user registration.
///
/// This widget presents a form that collects:
/// 1. Core credentials (Username, Email, Password).
/// 2. Dynamic preferences (Preferred Cuisines).
/// 3. Dynamic health info (Dietary Restrictions).
///
/// It uses a [StatefulWidget] because it needs to manage the state of
/// multiple text controllers and dynamic lists of input fields.
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  /// GlobalKey uniquely identifies the [Form] widget and allows validation.
  final _formKey = GlobalKey<FormState>();
  
  // --- STATIC CONTROLLERS ---
  // These manage the text input for the fixed fields at the top of the form.
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  // --- DYNAMIC CONTROLLERS ---
  // These lists grow and shrink as the user adds or removes fields.
  final List<TextEditingController> _cuisineControllers = [];
  final List<TextEditingController> _dietaryControllers = [];

  /// Cleans up resources when the widget is removed from the tree.
  ///
  /// It is crucial to dispose of *every* controller, including those
  /// in the dynamic lists, to prevent memory leaks.
  @override
  void dispose() {
    // Dispose static controllers
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    
    // Dispose dynamic cuisine controllers
    for (var c in _cuisineControllers) {
      c.dispose();
    }
    
    // Dispose dynamic dietary controllers
    for (var c in _dietaryControllers) {
      c.dispose();
    }
    super.dispose();
  }

  // --- Dynamic Field Logic ---

  /// Adds a new input field for Cuisines.
  ///
  /// Creates a new [TextEditingController], adds it to the list,
  /// and calls [setState] to refresh the UI.
  void _addCuisine() {
    setState(() {
      _cuisineControllers.add(TextEditingController());
    });
  }

  /// Removes a specific Cuisine input field.
  ///
  /// [index] - The position of the item to remove.
  /// Note: We must dispose of the controller *before* removing it from the list.
  void _removeCuisine(int index) {
    setState(() {
      _cuisineControllers[index].dispose();
      _cuisineControllers.removeAt(index);
    });
  }

  /// Adds a new input field for Dietary Restrictions.
  void _addDietary() {
    setState(() {
      _dietaryControllers.add(TextEditingController());
    });
  }

  /// Removes a specific Dietary Restriction input field.
  void _removeDietary(int index) {
    setState(() {
      _dietaryControllers[index].dispose();
      _dietaryControllers.removeAt(index);
    });
  }
  // ---------------------------

  /// Validates the form and executes the registration logic.
  ///
  /// If [_formKey.currentState.validate()] returns true, all [validator] functions
  /// in the TextFields have passed.
  void _handleRegister() {
    if (_formKey.currentState!.validate()) {
      // Simulate registration success
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account Created! Please Login.')),
      );
      // Navigate back to the previous screen (Login Page)
      Navigator.pop(context); 
    }
  }

  /// A helper widget builder for section headers (e.g., "Preferred Cuisines").
  ///
  /// Includes a title text and an "Add" button icon.
  /// * [title]: The text to display.
  /// * [onAdd]: The callback function to execute when the plus icon is pressed.
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
      // Transparent AppBar allows the clean design to shine through
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      // SingleChildScrollView is essential here to prevent "pixel overflow" errors
      // when the keyboard opens or when the dynamic lists get long.
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(25, 0, 25, 25),
        child: Column(
          children: [
            // Standardized Header
            const AuthHeader(
              title: "Create Account",
              subtitle: "Join us and decide what to eat.",
            ),

            // AuthBox provides the white card background and shadow
            AuthBox(
              child: Form(
                key: _formKey, // Connects the GlobalKey to the Form
                child: Column(
                  children: [
                    // --- Personal Info Section ---
                    
                    // Username Field
                    AuthTextField(
                      labelText: "Username",
                      obscureText: false,
                      controller: _usernameController,
                      prefixIcon: const Icon(Icons.person_outline),
                      validator: (val) => val!.isEmpty ? 'Required' : null,
                    ),
                    
                    // Email Field
                    AuthTextField(
                      labelText: "Email",
                      obscureText: false,
                      controller: _emailController,
                      prefixIcon: const Icon(Icons.email_outlined),
                      validator: (val) => !val!.contains('@') ? 'Invalid Email' : null,
                    ),
                    
                    // Password Field
                    AuthTextField(
                      labelText: "Password",
                      obscureText: true,
                      controller: _passwordController,
                      prefixIcon: const Icon(Icons.lock_outline),
                      validator: (val) => val!.length < 8 ? 'Min 8 chars' : null,
                    ),
                    
                    // Confirm Password Field
                    AuthTextField(
                      labelText: "Confirm Password",
                      obscureText: true,
                      controller: _confirmPasswordController,
                      // FIXED: Changed to valid icon 'Icons.lock'
                      prefixIcon: const Icon(Icons.lock), 
                      // Validates that this field matches the Password field
                      validator: (val) => val != _passwordController.text ? 'Mismatch' : null,
                    ),

                    const SizedBox(height: 10),
                    const Divider(),
                    const SizedBox(height: 10),

                    // --- Dynamic Preferences Section ---
                    
                    // 1. Cuisines Header
                    _buildSectionTitle("Preferred Cuisines", _addCuisine),
                    
                    // 1b. Render List of Cuisine Fields
                    // We use the spread operator (...) and .asMap() to access the index
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
                            // Delete Button for this specific row
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _removeCuisine(entry.key),
                            ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 10),

                    // 2. Dietary Restrictions Header
                    _buildSectionTitle("Dietary Restrictions", _addDietary),
                    
                    // 2b. Render List of Dietary Fields
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
                            // Delete Button for this specific row
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
                    // Triggers the _handleRegister function
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