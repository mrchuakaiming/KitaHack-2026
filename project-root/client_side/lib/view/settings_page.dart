import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'common_widgets.dart'; // Ensure this matches your file structure
import 'bottom_nav.dart';
import '../viewmodels/settings_page_vm.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // UI Controllers
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();

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

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // --- CONFIRMATION DIALOG HELPER ---
  Future<bool> _showConfirmation(String title, String content, {bool isDangerous = false}) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: TextStyle(color: isDangerous ? Colors.red : Colors.black)),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text("Confirm", style: TextStyle(fontWeight: FontWeight.bold, color: isDangerous ? Colors.red : kPrimaryColor)),
          ),
        ],
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SettingsViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text("Settings"), automaticallyImplyLeading: false),
      body: vm.isLoading
          ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- 1. PROFILE SECTION ---
                  const Text("Profile", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  AuthBox(
                    child: Column(
                      children: [
                        AuthTextField(
                          labelText: "Username",
                          obscureText: false,
                          controller: _usernameController,
                          readOnly: !vm.isEditing,
                          prefixIcon: const Icon(Icons.person),
                        ),
                        AuthTextField(
                          labelText: "Email",
                          obscureText: false,
                          controller: _emailController,
                          readOnly: true, // Email usually cannot be changed easily
                          prefixIcon: const Icon(Icons.email),
                        ),
                        const SizedBox(height: 10),
                        
                        // Edit / Save Button
                        Align(
                          alignment: Alignment.centerRight,
                          child: vm.isEditing
                            ? ElevatedButton.icon(
                                icon: const Icon(Icons.check, size: 16),
                                label: const Text("Save Changes"),
                                style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, foregroundColor: Colors.white),
                                onPressed: () async {
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
                  const Text("Account", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 5)]),
                    child: Column(
                      children: [
                        // Change Password (Navigates to ChangePasswordPage)
                        ListTile(
                          leading: const Icon(Icons.lock_reset, color: Colors.blue),
                          title: const Text("Change Password"),
                          subtitle: const Text("Update your login credentials"),
                          onTap: () {
                            Navigator.pushNamed(context, '/change_password');
                          },
                        ),
                        const Divider(height: 1),
                        
                        // Clear History
                        ListTile(
                          leading: const Icon(Icons.cleaning_services, color: Colors.orange),
                          title: const Text("Clear History"),
                          subtitle: const Text("Remove all past room data"),
                          onTap: () async {
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
                  const Text("Danger Zone", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade100)),
                    child: ListTile(
                      leading: const Icon(Icons.delete_forever, color: Colors.red),
                      title: const Text("Delete Account", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      subtitle: const Text("Permanently remove all data"),
                      onTap: () async {
                        bool confirm = await _showConfirmation(
                          "Delete Account?", 
                          "This action is irreversible. All your data will be lost forever.", 
                          isDangerous: true
                        );
                        
                        if (confirm) {
                          bool success = await vm.rmAccount();
                          if (success && mounted) {
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
      bottomNavigationBar: const CustomBottomNav(currentIndex: 2), // Highlight Profile Tab
    );
  }
}