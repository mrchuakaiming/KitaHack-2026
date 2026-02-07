import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'common_widgets.dart'; 
import '../viewmodels/register_vm.dart';

/// **Step 2: Profile Registration (Executor)**
///
/// **Role:**
/// 1. Receives Email/Password from Step 1.
/// 2. Collects Profile Info (Username, Dietary, Cuisines).
/// 3. Calls the atomic `registerUser` on the ViewModel to finalize the account.
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  
  // -- Controllers for Profile --
  final TextEditingController _usernameController = TextEditingController();
  
  // -- Dynamic Lists --
  // Note: In a real app, you might use a more robust list editor.
  // Here we use simple controllers for demo purposes.
  final List<TextEditingController> _cuisineControllers = [];
  final List<TextEditingController> _dietaryControllers = [];

  @override
  void dispose() {
    _usernameController.dispose();
    for (var c in _cuisineControllers) {c.dispose();}
    for (var c in _dietaryControllers) {c.dispose();}
    super.dispose();
  }

  /// Retrieves the Email/Password passed from Step 1.
  /// Returns `null` if arguments are missing or invalid.
  Map<String, dynamic>? _getStep1Args() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      return args;
    }
    return null;
  }

  /// Triggers the Atomic Registration Logic.
  void _handleRegister() async {
    // 1. Retrieve Step 1 Data
    final args = _getStep1Args();
    
    // Safety Fallback: If deep-linked or hot-reloaded without args, go back.
    if (args == null) {
      Navigator.pushReplacementNamed(context, '/verify_email');
      return;
    }

    if (_formKey.currentState!.validate()) {
      final vm = context.read<RegisterViewModel>();

      // 2. Execute Atomic Registration
      // We combine Step 1 data (Args) + Step 2 data (Controllers)
      bool success = await vm.registerUser(
        email: args['email'],
        password: args['password'],
        username: _usernameController.text,
        // Convert controllers to plain string lists
        cuisines: _cuisineControllers.map((c) => c.text).where((t) => t.isNotEmpty).toList(),
        dietary: _dietaryControllers.map((c) => c.text).where((t) => t.isNotEmpty).toList(),
      );

      // 3. Navigate on Success
      if (success && mounted) {
        // Clear history so user can't "back" into registration
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      }
    }
  }

  // --- UI HELPERS for Dynamic Lists ---

  void _addItem(List<TextEditingController> list) {
    setState(() {
      list.add(TextEditingController());
    });
  }

  void _removeItem(List<TextEditingController> list, int index) {
    setState(() {
      list[index].dispose();
      list.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RegisterViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text("Complete Profile")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const AuthHeader(title: "Step 2", subtitle: "Tell us about your taste"),
            
            AuthBox(
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // --- Username ---
                    AuthTextField(
                      labelText: "Username",
                      obscureText: false,
                      controller: _usernameController,
                      prefixIcon: const Icon(Icons.person),
                      validator: (val) => val!.isEmpty ? "Required" : null,
                    ),
                    const SizedBox(height: 20),

                    // --- Dynamic Cuisines ---
                    _buildSectionHeader("Favorite Cuisines", () => _addItem(_cuisineControllers)),
                    ..._buildDynamicList(_cuisineControllers),

                    const SizedBox(height: 20),

                    // --- Dynamic Dietary ---
                    _buildSectionHeader("Dietary Restrictions", () => _addItem(_dietaryControllers)),
                    ..._buildDynamicList(_dietaryControllers),

                    const SizedBox(height: 30),

                    // --- Error Display ---
                    if (vm.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          vm.errorMessage!, 
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    // --- Register Button ---
                    AuthButton(
                      text: vm.isLoading ? "Creating Account..." : "Finish Registration",
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

  Widget _buildSectionHeader(String title, VoidCallback onAdd) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        IconButton(
          onPressed: onAdd,
          icon: const Icon(Icons.add_circle, color: Color(0xFFFF7043)),
        ),
      ],
    );
  }

  List<Widget> _buildDynamicList(List<TextEditingController> controllers) {
    return controllers.asMap().entries.map((entry) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Row(
          children: [
            Expanded(
              child: AuthTextField(
                labelText: "Item ${entry.key + 1}",
                obscureText: false,
                controller: entry.value,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _removeItem(controllers, entry.key),
            ),
          ],
        ),
      );
    }).toList();
  }
}