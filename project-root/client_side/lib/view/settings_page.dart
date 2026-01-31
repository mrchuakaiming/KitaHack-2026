import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'common_widgets.dart';
import 'bottom_nav.dart';
import '../viewmodels/settings_page_vm.dart';

/// The user profile and application settings screen.
///
/// This widget serves as the central hub for user account management.
/// It provides functionality for:
/// 1. **Profile Editing:** Viewing and updating the username.
/// 2. **Account Security:** Triggering password resets (via email).
/// 3. **Data Management:** Clearing local history or permanently deleting the account.
/// 4. **Session Management:** Logging out of the application.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // --- UI CONTROLLERS ---
  // TextControllers manage the input fields for the profile section.
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();

  /// Initializes the state and loads user data.
  ///
  /// Calls [SettingsViewModel.loadProfile] to fetch the latest user details
  /// (like username and email) from the backend/service layer and populates
  /// the text controllers.
  @override
  void initState() {
    super.initState();
    // Load initial profile data
    final vm = context.read<SettingsViewModel>();
    vm.loadProfile().then((_) {
      _usernameController.text = vm.username;
      _emailController.text = vm.email;
    });
  }

  /// Disposes controllers to free up system resources.
  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // --- CONFIRMATION DIALOG HELPER ---

  /// Displays a generic modal dialog to confirm sensitive actions.
  ///
  /// This reusable function is used for actions like "Clear History" or "Delete Account".
  ///
  /// * [title]: The headline of the dialog.
  /// * [content]: The explanatory text warning the user of consequences.
  /// * [isDangerous]: If true, styles the "Confirm" button in red to indicate risk.
  ///
  /// Returns `true` if the user clicked "Confirm", otherwise `false`.
  Future<bool> _showConfirmation(String title, String content, {bool isDangerous = false}) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: TextStyle(color: isDangerous ? Colors.red : Colors.black)),
        content: Text(content),
        actions: [
          // Cancel Button
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          // Confirm Button (styled based on danger level)
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text("Confirm", style: TextStyle(fontWeight: FontWeight.bold, color: isDangerous ? Colors.red : kPrimaryColor)),
          ),
        ],
      ),
    ) ?? false; // Default to false if dialog is dismissed by tapping outside
  }

  @override
  Widget build(BuildContext context) {
    // Watch the ViewModel for changes (e.g., loading state, edit mode toggle)
    final vm = context.watch<SettingsViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text("Settings"), automaticallyImplyLeading: false),
      
      // Show a loading spinner if the VM is performing an async operation
      body: vm.isLoading
          ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- 1. PROFILE SECTION ---
                  // Handles Username and Email display/editing.
                  const Text("Profile", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  AuthBox(
                    child: Column(
                      children: [
                        // Username Field (Editable based on vm.isEditing)
                        AuthTextField(
                          labelText: "Username",
                          obscureText: false,
                          controller: _usernameController,
                          readOnly: !vm.isEditing,
                          prefixIcon: const Icon(Icons.person),
                        ),
                        // Email Field (Always Read-Only)
                        AuthTextField(
                          labelText: "Email",
                          obscureText: false,
                          controller: _emailController,
                          readOnly: true, // Email usually cannot be changed easily
                          prefixIcon: const Icon(Icons.email),
                        ),
                        const SizedBox(height: 10),
                        
                        // Edit / Save Button Toggle
                        Align(
                          alignment: Alignment.centerRight,
                          child: vm.isEditing
                            ? ElevatedButton.icon(
                                icon: const Icon(Icons.check, size: 16),
                                label: const Text("Save Changes"),
                                style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, foregroundColor: Colors.white),
                                onPressed: () async {
                                  // Save changes via VM
                                  await vm.updateProfile(_usernameController.text);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile Updated")));
                                  }
                                },
                              )
                            : TextButton.icon(
                                icon: const Icon(Icons.edit, size: 16, color: kPrimaryColor),
                                label: const Text("Edit Profile", style: TextStyle(color: kPrimaryColor)),
                                onPressed: () => vm.toggleEdit(),
                              ),
                        )
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // --- 2. ACCOUNT ACTIONS ---
                  // General account maintenance (Passwords, History, Logout).
                  const Text("Account", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 5)]),
                    child: Column(
                      children: [
                        // Reset Password (Navigates to the Reset Password Flow)
                        ListTile(
                          leading: const Icon(Icons.lock_reset, color: Colors.blue),
                          title: const Text("Reset Password"), 
                          subtitle: const Text("Send a reset link to your email"),
                          onTap: () {
                            // Navigate to the shared Reset Password screen
                            Navigator.pushNamed(context, '/reset_password');
                          },
                        ),
                        const Divider(height: 1),
                        
                        // Clear History
                        ListTile(
                          leading: const Icon(Icons.cleaning_services, color: Colors.orange),
                          title: const Text("Clear History"),
                          subtitle: const Text("Remove all past room data"),
                          onTap: () async {
                            // Require user confirmation before clearing data
                            bool confirm = await _showConfirmation("Clear History?", "This will remove all your hosted rooms and preferences.");
                            if (confirm) {
                              await vm.clearData();
                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("History Cleared")));
                            }
                          },
                        ),
                        const Divider(height: 1),

                        // Logout
                        ListTile(
                          leading: const Icon(Icons.exit_to_app, color: Colors.black),
                          title: const Text("Log Out"),
                          onTap: () => vm.logout(context),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // --- 3. DANGER ZONE ---
                  // Destructive actions involving permanent data loss.
                  const Text("Danger Zone", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade100)),
                    child: ListTile(
                      leading: const Icon(Icons.delete_forever, color: Colors.red),
                      title: const Text("Delete Account", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      subtitle: const Text("Permanently remove all data"),
                      onTap: () async {
                        // Strict double-confirmation for account deletion
                        bool confirm = await _showConfirmation(
                          "Delete Account?", 
                          "This action is irreversible. All your data will be lost forever.", 
                          isDangerous: true
                        );
                        
                        if (confirm) {
                          bool success = await vm.rmAccount();
                          if (success && mounted) {
                            // Redirect to login screen on success
                            Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                          }
                        }
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                ],
              ),
            ),
      // Uses the custom bottom navigation bar, highlighting the "Profile" tab (index 2)
      bottomNavigationBar: const CustomBottomNav(currentIndex: 2), 
    );
  }
}