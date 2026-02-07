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
  
  // -- Hardcoded Data Lists --
  final List<String> _availableCuisines = [
    'Italian', 'Chinese', 'Japanese', 'Mexican', 
    'Indian', 'Thai', 'American', 'French', 
    'Mediterranean', 'Korean', 'Vietnamese', 'Fast Food'
  ];

  final List<String> _availableDietary = [
    'Vegetarian', 'Vegan', 'Gluten-Free', 
    'Halal', 'Kosher', 'Nut-Free', 
    'Dairy-Free', 'Low-Carb', 'None'
  ];

  // -- Selection State --
  final List<String> _selectedCuisines = [];
  final List<String> _selectedDietary = [];

  @override
  void dispose() {
    _usernameController.dispose();
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
      bool success = await vm.registerUser(
        email: args['email'],
        password: args['password'],
        username: _usernameController.text,
        // Pass the selected lists directly
        cuisines: _selectedCuisines,
        dietary: _selectedDietary,
      );

      // 3. Navigate on Success
      if (success && mounted) {
        // Clear history so user can't "back" into registration
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      }
    }
  }

  // --- UI Helpers for Chips ---
  
  void _toggleSelection(List<String> list, String item, bool isSelected) {
    setState(() {
      if (isSelected) {
        list.add(item);
      } else {
        list.remove(item);
      }
    });
  }

  Widget _buildChipSection(String title, List<String> options, List<String> selectedList) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title, 
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 14)
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8.0,
          runSpacing: 4.0,
          children: options.map((option) {
            final isSelected = selectedList.contains(option);
            return FilterChip(
              label: Text(option),
              selected: isSelected,
              selectedColor: const Color(0xFFFF7043).withOpacity(0.2),
              checkmarkColor: const Color(0xFFFF7043),
              labelStyle: TextStyle(
                color: isSelected ? const Color(0xFFFF7043) : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              onSelected: (bool selected) {
                _toggleSelection(selectedList, option, selected);
              },
            );
          }).toList(),
        ),
      ],
    );
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- Username ---
                    AuthTextField(
                      labelText: "Username",
                      obscureText: false,
                      controller: _usernameController,
                      prefixIcon: const Icon(Icons.person),
                      validator: (val) => val!.isEmpty ? "Required" : null,
                    ),
                    const SizedBox(height: 25),

                    // --- Cuisines Chips ---
                    _buildChipSection("Favorite Cuisines", _availableCuisines, _selectedCuisines),

                    const SizedBox(height: 25),

                    // --- Dietary Chips ---
                    _buildChipSection("Dietary Restrictions", _availableDietary, _selectedDietary),

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
}