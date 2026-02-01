import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'common_widgets.dart'; 
import '../viewmodels/settings_page_vm.dart';
import '../services/firestore_service.dart'; // Direct import for fetching initial data
import '../models/user.dart';

/// The User Profile and Settings Screen.
///
/// **Architecture Note:**
/// Since [SettingsViewModel] is restricted to *Actions Only* (Update/Reset/Delete),
/// this View is responsible for fetching the initial [UserModel] state directly
/// from [FirestoreService] to populate the text fields.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // --- STATE ---
  late TextEditingController _usernameController;
  List<TextEditingController> _cuisineControllers = [];
  List<TextEditingController> _dietaryControllers = [];
  
  bool _isLoadingData = true; // Local loading state for fetching initial data
  bool _isEditing = false;    // Local UI state for Edit Mode

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    _fetchUserData();
  }

  /// Fetches the current user's data to populate the form.
  /// This is done here because the VM is restricted to actions only.
  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Direct call to service to get data
      UserModel? userModel = await FirestoreService().getUser(user.uid);
      
      if (userModel != null && mounted) {
        _populateControllers(userModel);
      }
    }
    
    if (mounted) setState(() => _isLoadingData = false);
  }

  /// Syncs the TextControllers with the fetched data.
  void _populateControllers(UserModel user) {
    _usernameController.text = user.username;
    
    _cuisineControllers = user.preferredCuisine
        .map((t) => TextEditingController(text: t))
        .toList();
    
    _dietaryControllers = user.dietaryRestrictions
        .map((t) => TextEditingController(text: t))
        .toList();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    for (var c in _cuisineControllers) c.dispose();
    for (var c in _dietaryControllers) c.dispose();
    super.dispose();
  }

  // --- ACTIONS (Delegated to ViewModel) ---

  /// Collects data from controllers and calls [SettingsViewModel.updateProfile].
  void _handleSave() async {
    final vm = context.read<SettingsViewModel>();
    
    // Extract Strings from Controllers
    final cuisines = _cuisineControllers.map((c) => c.text).toList();
    final dietary = _dietaryControllers.map((c) => c.text).toList();

    bool success = await vm.updateProfile(
      username: _usernameController.text,
      cuisines: cuisines,
      dietary: dietary,
    );

    if (success && mounted) {
      setState(() => _isEditing = false); // Exit edit mode on success
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile Updated!"), backgroundColor: Colors.green),
      );
    }
  }

  /// Calls [SettingsViewModel.resetPassword].
  void _handleResetPassword() async {
    final vm = context.read<SettingsViewModel>();
    await vm.resetPassword();
    
    if (mounted) {
      // Check if VM set an error, otherwise assume success
      if (vm.errorMessage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Password reset email sent!")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(vm.errorMessage!), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Shows confirmation dialog and calls [SettingsViewModel.deleteAccount].
  void _handleDeleteAccount() async {
    // 1. Confirm Dialog
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Account?"),
        content: const Text("This action is permanent and cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final vm = context.read<SettingsViewModel>();
      
      // 2. Perform Deletion
      bool success = await vm.deleteAccount();

      if (success && mounted) {
        // 3. Navigate to Login (Clear history)
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      } else if (mounted) {
        // Show Error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(vm.errorMessage ?? "Failed to delete"), backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- DYNAMIC FIELDS HELPERS ---
  
  void _addCuisine() => setState(() => _cuisineControllers.add(TextEditingController()));
  void _addDietary() => setState(() => _dietaryControllers.add(TextEditingController()));

  @override
  Widget build(BuildContext context) {
    // Watch VM for loading state during actions (Save/Delete)
    final vm = context.watch<SettingsViewModel>();

    // Show spinner if we are fetching initial data OR if VM is performing an action
    if (_isLoadingData || vm.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: kPrimaryColor)));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          // Edit/Save Toggle Button
          IconButton(
            icon: Icon(_isEditing ? Icons.save : Icons.edit),
            onPressed: _isEditing ? _handleSave : () => setState(() => _isEditing = true),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // --- HEADER ---
            AuthBox(
              child: Column(
                children: [
                  const Icon(Icons.account_circle, size: 80, color: kPrimaryColor),
                  const SizedBox(height: 10),
                  // Username Field (Editable based on state)
                  AuthTextField(
                    labelText: "Username",
                    obscureText: false,
                    controller: _usernameController,
                    readOnly: !_isEditing,
                    prefixIcon: const Icon(Icons.person),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // --- LISTS (Cuisine / Dietary) ---
            if (_isEditing) ...[
               // Edit Mode: Show Add/Delete buttons
               _buildEditListSection("Cuisines", _cuisineControllers, _addCuisine),
               const SizedBox(height: 20),
               _buildEditListSection("Dietary Restrictions", _dietaryControllers, _addDietary),
            ] else ...[
               // View Mode: Show Read-Only Chips
               // We extract text from controllers to display in chips
               _buildReadListSection("Cuisines", _cuisineControllers.map((c) => c.text).toList()),
               const SizedBox(height: 10),
               _buildReadListSection("Dietary Restrictions", _dietaryControllers.map((c) => c.text).toList()),
            ],

            const SizedBox(height: 30),

            // --- ACCOUNT ACTIONS (View Mode Only) ---
            if (!_isEditing) ...[
              AuthButton(
                text: "Reset Password",
                onPressed: _handleResetPassword,
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _handleDeleteAccount,
                  child: const Text("Delete Account"),
                ),
              ),
              const SizedBox(height: 30),
              
              // Logout Button
               TextButton(
                onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false),
                child: const Text("Log Out", style: TextStyle(color: Colors.grey)),
              ),
            ]
          ],
        ),
      ),
    );
  }

  // --- WIDGET HELPERS ---

  Widget _buildReadListSection(String title, List<String> items) {
    return AuthBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          if (items.isEmpty)
            const Text("None set", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))
          else
            Wrap(
              spacing: 8,
              children: items.map((i) => Chip(label: Text(i))).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildEditListSection(String title, List<TextEditingController> controllers, VoidCallback onAdd) {
    return AuthBox(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.add_circle, color: kPrimaryColor), onPressed: onAdd),
            ],
          ),
          ...controllers.asMap().entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                Expanded(child: AuthTextField(labelText: "Item", obscureText: false, controller: e.value)),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => setState(() {
                    controllers[e.key].dispose();
                    controllers.removeAt(e.key);
                  }),
                )
              ],
            ),
          )),
        ],
      ),
    );
  }
}