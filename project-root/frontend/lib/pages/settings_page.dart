import 'package:flutter/material.dart';
import '../widgets/common_widgets.dart';
import '../widgets/custom_bottom_nav.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // --- Controllers ---
  final TextEditingController _usernameController = TextEditingController(text: "FoodieUser123");
  final TextEditingController _emailController = TextEditingController(text: "user@example.com"); 
  final FocusNode _usernameFocusNode = FocusNode(); // Controls keyboard focus

  final List<TextEditingController> _cuisineControllers = [];
  final List<TextEditingController> _dietaryControllers = [];

  bool _isEditingUsername = false;

  @override
  void initState() {
    super.initState();
    _addItem(_cuisineControllers, "Japanese");
    _addItem(_cuisineControllers, "Italian");
    _addItem(_dietaryControllers, "No Nuts");
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _usernameFocusNode.dispose();
    for (var c in _cuisineControllers) c.dispose();
    for (var c in _dietaryControllers) c.dispose();
    super.dispose();
  }

  void _addItem(List<TextEditingController> list, [String? text]) {
    setState(() {
      list.add(TextEditingController(text: text ?? ""));
    });
  }

  void _removeItem(List<TextEditingController> list, int index) {
    setState(() {
      list[index].dispose();
      list.removeAt(index);
    });
  }

  // --- NEW: Delete Account Logic ---
  void _handleDeleteAccount() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Delete Account?"),
          content: const Text(
            "Are you sure you want to delete your account? This action cannot be undone and you will lose all your data.",
            style: TextStyle(color: Colors.black87),
          ),
          actions: [
            // Cancel Button
            TextButton(
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
              },
            ),
            // Confirm Delete Button
            TextButton(
              child: const Text("Delete", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog first
                
                // Show confirmation message
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Account deleted successfully.'),
                    backgroundColor: Colors.red,
                  ),
                );

                // Redirect to Login and clear history
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (Route<dynamic> route) => false);
              },
            ),
          ],
        );
      },
    );
  }
  // ---------------------------------

  Widget _buildPreferenceSection({
    required String title,
    required List<TextEditingController> controllers,
    required VoidCallback onAdd,
    required Function(int) onRemove,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: onAdd,
            ),
          ],
        ),
        if (controllers.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text("No preferences set", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
          )
        else
          ...controllers.asMap().entries.map((entry) {
            int index = entry.key;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 45,
                      child: TextField(
                        controller: entry.value,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => onRemove(index),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Settings", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Info
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.grey.shade300,
                  child: const Icon(Icons.person, size: 40, color: Colors.white),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: TextField(
                    controller: _usernameController,
                    focusNode: _usernameFocusNode,
                    readOnly: !_isEditingUsername, 
                    decoration: InputDecoration(
                      labelText: "Username",
                      border: const OutlineInputBorder(),
                      fillColor: _isEditingUsername ? Colors.white : Colors.grey.shade50,
                      filled: true,
                      suffixIcon: IconButton(
                        icon: Icon(_isEditingUsername ? Icons.check : Icons.edit, color: Colors.black),
                        onPressed: () {
                          setState(() {
                            _isEditingUsername = !_isEditingUsername;
                          });
                          if (_isEditingUsername) {
                            _usernameFocusNode.requestFocus();
                          }
                        },
                      ),
                    ),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                const SizedBox(width: 75), 
                Expanded(
                  child: TextField(
                    controller: _emailController,
                    readOnly: true, 
                    decoration: InputDecoration(
                      labelText: "Email",
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.grey.shade200,
                      prefixIcon: const Icon(Icons.email_outlined, size: 20),
                    ),
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),
            const Divider(),
            const SizedBox(height: 10),

            // Preferences
            const Row(
              children: [
                Text("Preferences", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                SizedBox(width: 10),
                Icon(Icons.edit, size: 20, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 15),

            _buildPreferenceSection(
              title: "Preferred Cuisines",
              controllers: _cuisineControllers,
              onAdd: () => _addItem(_cuisineControllers),
              onRemove: (index) => _removeItem(_cuisineControllers, index),
            ),
            const SizedBox(height: 20),
            _buildPreferenceSection(
              title: "Dietary Restrictions",
              controllers: _dietaryControllers,
              onAdd: () => _addItem(_dietaryControllers),
              onRemove: (index) => _removeItem(_dietaryControllers, index),
            ),

            const SizedBox(height: 40),

            // Change Password
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                   Navigator.pushNamed(context, '/change_password');
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(15),
                  side: const BorderSide(color: Colors.black),
                ),
                child: const Text("Change Password", style: TextStyle(color: Colors.black)),
              ),
            ),
            const SizedBox(height: 15),

            // Save Changes
            AuthButton(
              text: "Save Changes",
              onPressed: () {
                setState(() {
                  _isEditingUsername = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Settings Saved!'), backgroundColor: Colors.green),
                );
              },
            ),
            const SizedBox(height: 30),
            
            const Divider(), // Separator for Danger Zone

            // Logout
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).pushNamedAndRemoveUntil('/login', (Route<dynamic> route) => false);
                },
                child: const Text("Logout", style: TextStyle(color: Colors.black54, fontSize: 16)),
              ),
            ),

            // --- Delete Account Button ---
            Center(
              child: TextButton(
                onPressed: _handleDeleteAccount,
                child: const Text(
                  "Delete Account",
                  style: TextStyle(color: Colors.red, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: const CustomBottomNav(currentIndex: 2),
    );
  }
}