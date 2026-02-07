import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'common_widgets.dart'; 
import '../viewmodels/settings_page_vm.dart';
import '../services/firestore_service.dart'; 
import '../models/user.dart';

// [IMPORT] Analytics for UI interactions (Log Out)
import '../services/analytics_service.dart';

/// **User Profile and Settings Screen**
///
/// **Design Pattern:**
/// This view acts as a "Hybrid Consumer":
/// 1.  **Read Operations:** Fetches initial data directly from [FirestoreService]
///     inside `initState`. This avoids complicating the ViewModel with read-state.
/// 2.  **Write Operations:** Delegates all changes (Save, Delete) to [SettingsViewModel].
///
/// **UI Features:**
/// - **Edit Mode:** Toggles between Read-Only chips and Editable text fields.
/// - **Confirmation Dialogs:** Protects against accidental account deletion.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // ====================================================================
  // UI STATE
  // ====================================================================
  
  // Controllers for form fields
  late TextEditingController _usernameController;
  List<TextEditingController> _cuisineControllers = [];
  List<TextEditingController> _dietaryControllers = [];
  
  /// Loading state specifically for the initial data fetch.
  bool _isLoadingData = true; 
  
  /// Toggles the UI between "View Mode" and "Edit Mode".
  bool _isEditing = false;    

  // ====================================================================
  // LIFECYCLE
  // ====================================================================

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    
    // Trigger initial data load
    _fetchUserData();
  }

  /// Fetches the user's current profile from Firestore to populate the UI.
  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // We use FirestoreService directly here because the VM is for Actions only.
      UserModel? userModel = await FirestoreService().getUser(user.uid);
      
      if (userModel != null && mounted) {
        _populateControllers(userModel);
      }
    }
    
    if (mounted) setState(() => _isLoadingData = false);
  }

  /// Maps the User Model data to the UI controllers.
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
    for (var c in _cuisineControllers) {c.dispose();}
    for (var c in _dietaryControllers) {c.dispose();}
    super.dispose();
  }

  // ====================================================================
  // ACTION HANDLERS
  // ====================================================================

  /// Collects inputs and calls the VM to update the profile.
  void _handleSave() async {
    final vm = context.read<SettingsViewModel>();
    
    // Extract raw strings from controllers
    final cuisines = _cuisineControllers.map((c) => c.text).toList();
    final dietary = _dietaryControllers.map((c) => c.text).toList();

    bool success = await vm.updateProfile(
      username: _usernameController.text,
      cuisines: cuisines,
      dietary: dietary,
    );

    if (success && mounted) {
      setState(() => _isEditing = false); // Exit edit mode
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile Updated!"), backgroundColor: Colors.green),
      );
    }
  }

  /// Calls the VM to send a password reset email.
  void _handleResetPassword() async {
    final vm = context.read<SettingsViewModel>();
    await vm.resetPassword();
    
    if (mounted) {
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

  /// Handles the Account Deletion flow with a safety check.
  void _handleDeleteAccount() async {
    // 1. Show Confirmation Pop-up
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Account?"),
        content: const Text(
          "This action is permanent.\nAll your preferences, history, and hosted rooms will be wiped.",
          style: TextStyle(color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false), 
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text("Delete Forever", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    // 2. Perform Deletion if Confirmed
    if (confirm == true && mounted) {
      final vm = context.read<SettingsViewModel>();
      
      bool success = await vm.deleteAccount();

      if (success && mounted) {
        // 3. Navigate to Login (Clear Stack)
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      } else if (mounted) {
        // Show Error (likely "Requires Recent Login")
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(vm.errorMessage ?? "Failed to delete account"), 
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
  
  void _handleLogout() async {
    // Log the event explicitly before navigation
    await AnalyticsService().logEvent('logout');
    if (mounted) {
      await FirebaseAuth.instance.signOut();
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  // ====================================================================
  // DYNAMIC LIST HELPERS
  // ====================================================================
  
  void _addCuisine() => setState(() => _cuisineControllers.add(TextEditingController()));
  void _addDietary() => setState(() => _dietaryControllers.add(TextEditingController()));

  // ====================================================================
  // UI BUILD
  // ====================================================================

  @override
  Widget build(BuildContext context) {
    // Watch VM to show loading spinner during Async Actions
    final vm = context.watch<SettingsViewModel>();

    // Global loading state check
    if (_isLoadingData || vm.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: kPrimaryColor))
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          // Toggle Edit/Save
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
            // --- PROFILE HEADER ---
            AuthBox(
              child: Column(
                children: [
                  const Icon(Icons.account_circle, size: 80, color: kPrimaryColor),
                  const SizedBox(height: 10),
                  AuthTextField(
                    labelText: "Username",
                    obscureText: false,
                    controller: _usernameController,
                    readOnly: !_isEditing, // Only editable in Edit Mode
                    prefixIcon: const Icon(Icons.person),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // --- PREFERENCES LISTS ---
            if (_isEditing) ...[
               // Edit Mode: Add/Remove items
               _buildEditListSection("Cuisines", _cuisineControllers, _addCuisine),
               const SizedBox(height: 20),
               _buildEditListSection("Dietary Restrictions", _dietaryControllers, _addDietary),
            ] else ...[
               // Read Mode: Display Chips
               _buildReadListSection("Cuisines", _cuisineControllers.map((c) => c.text).toList()),
               const SizedBox(height: 10),
               _buildReadListSection("Dietary Restrictions", _dietaryControllers.map((c) => c.text).toList()),
            ],

            const SizedBox(height: 30),

            // --- ACCOUNT ACTIONS (Read Mode Only) ---
            // We hide these during editing to prevent state conflicts
            if (!_isEditing) ...[
              AuthButton(
                text: "Reset Password",
                onPressed: _handleResetPassword,
              ),
              const SizedBox(height: 15),
              
              // Delete Button (Destructive)
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
              
              // Logout Text Link
               TextButton(
                onPressed: _handleLogout,
                child: const Text("Log Out", style: TextStyle(color: Colors.grey)),
              ),
            ]
          ],
        ),
      ),
    );
  }

  // --- SUB-WIDGETS ---

  /// Renders a read-only list of items as Chips.
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

  /// Renders an editable list of text fields with Delete buttons.
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