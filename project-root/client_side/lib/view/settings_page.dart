import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'common_widgets.dart'; 
import '../viewmodels/settings_page_vm.dart';

/// The User Profile and Settings Screen.
///
/// Allows the user to:
/// 1. View and Edit their Profile (Username, Cuisines, Dietary).
/// 2. Clear their Preferences.
/// 3. Delete their Account.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Controllers
  late TextEditingController _usernameController;
  // We use Lists of Controllers for dynamic fields
  List<TextEditingController> _cuisineControllers = [];
  List<TextEditingController> _dietaryControllers = [];

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    
    // Load data when page opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SettingsViewModel>().loadProfile().then((_) {
        _populateControllers();
      });
    });
  }

  /// Syncs the TextControllers with the ViewModel's data.
  /// Called on load and after saving/clearing data.
  void _populateControllers() {
    final vm = context.read<SettingsViewModel>();
    final user = vm.userModel;
    if (user != null) {
      _usernameController.text = user.username;
      
      // Reset and fill lists
      _cuisineControllers = user.preferredCuisine
          .map((t) => TextEditingController(text: t))
          .toList();
      _dietaryControllers = user.dietaryRestrictions
          .map((t) => TextEditingController(text: t))
          .toList();
      
      // Rebuild to show new data
      if (mounted) setState(() {}); 
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    for (var c in _cuisineControllers) c.dispose();
    for (var c in _dietaryControllers) c.dispose();
    super.dispose();
  }

  // --- ACTIONS ---

  /// Collects data from controllers and calls updateProfile.
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile Updated!"), backgroundColor: Colors.green),
      );
    }
  }

  /// Shows confirmation dialog and calls rmAccount.
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
      bool success = await vm.rmAccount();

      if (success && mounted) {
        // 3. Navigate to Login (Clear history)
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      } else if (mounted) {
        // Show Error (e.g. "Requires Recent Login")
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(vm.errorMessage ?? "Failed to delete"), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Calls clearData and refreshes the UI controllers.
  void _handleClearData() async {
    final vm = context.read<SettingsViewModel>();
    bool success = await vm.clearData();
    if (success && mounted) {
      _populateControllers(); // Refresh UI to show empty lists
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Preferences Cleared"), backgroundColor: Colors.green),
      );
    }
  }

  // --- DYNAMIC FIELDS HELPERS ---
  
  void _addCuisine() {
    setState(() => _cuisineControllers.add(TextEditingController()));
  }

  void _addDietary() {
    setState(() => _dietaryControllers.add(TextEditingController()));
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SettingsViewModel>();
    final user = vm.userModel;

    // Show loading spinner if initially fetching user
    if (vm.isLoading && user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          // Edit/Save Toggle Button
          IconButton(
            icon: Icon(vm.isEditing ? Icons.save : Icons.edit),
            onPressed: vm.isEditing ? _handleSave : vm.toggleEdit,
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
                  Text(user?.email ?? "No Email", style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 20),
                  
                  // Username Field (Editable based on state)
                  AuthTextField(
                    labelText: "Username",
                    obscureText: false,
                    controller: _usernameController,
                    readOnly: !vm.isEditing,
                    prefixIcon: const Icon(Icons.person),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // --- LISTS (Cuisine / Dietary) ---
            if (vm.isEditing) ...[
               // Edit Mode: Show Add/Delete buttons
               _buildEditListSection("Cuisines", _cuisineControllers, _addCuisine),
               const SizedBox(height: 20),
               _buildEditListSection("Dietary Restrictions", _dietaryControllers, _addDietary),
            ] else ...[
               // View Mode: Show Read-Only Chips
               _buildReadListSection("Cuisines", user?.preferredCuisine ?? []),
               const SizedBox(height: 10),
               _buildReadListSection("Dietary Restrictions", user?.dietaryRestrictions ?? []),
            ],

            const SizedBox(height: 30),

            // --- ACCOUNT ACTIONS (View Mode Only) ---
            if (!vm.isEditing) ...[
              AuthButton(
                text: "Clear Preferences",
                onPressed: _handleClearData,
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

  /// Builds a read-only list of chips.
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

  /// Builds an editable list of text fields with add/remove buttons.
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