import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'common_widgets.dart';
import '../viewmodels/register_vm.dart';

/// The second step of registration: Profile Completion.
///
/// **Context:**
/// This view is displayed AFTER the user has successfully verified their email
/// via [VerifyEmailPage]. The user is technically logged in (Auth-wise),
/// but their Firestore profile is empty.
///
/// **Logic:**
/// It collects `Username`, `Cuisines`, and `Dietary Restrictions` and calls
/// [RegisterViewModel.updateProfile].
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final TextEditingController _usernameController = TextEditingController();
  final List<TextEditingController> _cuisineControllers = [];
  final List<TextEditingController> _dietaryControllers = [];

  @override
  void dispose() {
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

  /// Gathers data and calls [RegisterViewModel.updateProfile].
  void _handleFinish() async {
    if (_formKey.currentState!.validate()) {
      final vm = context.read<RegisterViewModel>();
      
      // Convert Controllers to List<String>
      final cuisines = _cuisineControllers
          .map((c) => c.text)
          .where((t) => t.isNotEmpty)
          .toList();
      
      final dietary = _dietaryControllers
          .map((c) => c.text)
          .where((t) => t.isNotEmpty)
          .toList();

      // EXECUTE VM LOGIC
      bool success = await vm.updateProfile(
        username: _usernameController.text,
        cuisines: cuisines,
        dietaryRestrictions: dietary,
      );

      if (success && mounted) {
        // Success: Go to Home
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      }
    }
  }

  Widget _buildSectionTitle(String title, VoidCallback onAdd) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        IconButton(
          onPressed: onAdd,
          icon: const Icon(Icons.add_circle, color: kPrimaryColor),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RegisterViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Complete Profile"),
        automaticallyImplyLeading: false, // Prevent going back to Auth step
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            const AuthHeader(
              title: "One last thing...",
              subtitle: "Tell us what you like to eat.",
            ),

            AuthBox(
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Username
                    AuthTextField(
                      labelText: "Username",
                      obscureText: false,
                      controller: _usernameController,
                      prefixIcon: const Icon(Icons.person),
                      validator: (val) => val!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 15),

                    // Cuisines
                    _buildSectionTitle("Preferred Cuisines", _addCuisine),
                    ..._cuisineControllers.asMap().entries.map((e) => Row(
                      children: [
                        Expanded(child: AuthTextField(labelText: "Cuisine", obscureText: false, controller: e.value)),
                        IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _removeCuisine(e.key))
                      ],
                    )),

                    const SizedBox(height: 10),

                    // Dietary
                    _buildSectionTitle("Dietary Restrictions", _addDietary),
                    ..._dietaryControllers.asMap().entries.map((e) => Row(
                      children: [
                        Expanded(child: AuthTextField(labelText: "Restriction", obscureText: false, controller: e.value)),
                        IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _removeDietary(e.key))
                      ],
                    )),

                    const SizedBox(height: 20),

                    // Error
                    if (vm.errorMessage != null)
                      Text(vm.errorMessage!, style: const TextStyle(color: Colors.red)),

                    // Submit
                    AuthButton(
                      text: vm.isLoading ? "Saving..." : "Finish",
                      onPressed: vm.isLoading ? null : () => _handleFinish(),
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