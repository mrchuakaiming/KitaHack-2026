import 'package:flutter/material.dart';
import '../widgets/common_widgets.dart'; // Uses your Premium Widgets
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
  final FocusNode _usernameFocusNode = FocusNode();

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
    for (var c in _cuisineControllers) {
      c.dispose();
    }
    for (var c in _dietaryControllers) {
      c.dispose();
    }
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

  // --- Delete Account Logic (Preserved) ---
  void _handleDeleteAccount() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Delete Account?"),
          content: const Text(
            "Are you sure? This action cannot be undone.",
            style: TextStyle(color: Colors.black87),
          ),
          actions: [
            TextButton(
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text("Delete", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.of(context).pop(); 
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Account deleted.'), backgroundColor: Colors.red),
                );
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (Route<dynamic> route) => false);
              },
            ),
          ],
        );
      },
    );
  }

  // Helper for Section Headers (Reused from Register Page design)
  Widget _buildSectionHeader(String title, VoidCallback onAdd) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle, color: kPrimaryColor),
            onPressed: onAdd,
            tooltip: "Add Item",
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Main.dart handles background color
      appBar: AppBar(
        title: const Text("Settings", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          // Quick Logout Icon
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () {
               Navigator.of(context).pushNamedAndRemoveUntil('/login', (Route<dynamic> route) => false);
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          children: [
            // --- 1. Profile Avatar Section ---
            const SizedBox(height: 10),
            Center(
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))
                      ],
                    ),
                    child: const CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.white,
                      backgroundImage: AssetImage('assets/placeholder_user.png'), // Or remove backgroundImage if no asset
                      child: Icon(Icons.person, size: 50, color: Colors.grey),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: kPrimaryColor, shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 25),

            // --- 2. Identity Card ---
            AuthBox(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Identity", style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  
                  // Username
                  AuthTextField(
                    labelText: "Username",
                    obscureText: false,
                    controller: _usernameController,
                    focusNode: _usernameFocusNode,
                    readOnly: !_isEditingUsername, // Toggle logic
                    prefixIcon: const Icon(Icons.person_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_isEditingUsername ? Icons.check_circle : Icons.edit, 
                        color: _isEditingUsername ? Colors.green : Colors.grey),
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

                  // Email
                  AuthTextField(
                    labelText: "Email",
                    obscureText: false,
                    controller: _emailController,
                    readOnly: true, // Always locked
                    prefixIcon: const Icon(Icons.email_outlined),
                    suffixIcon: const Icon(Icons.lock, size: 18, color: Colors.grey), // Visual cue it's locked
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // --- 3. Taste Profile Card ---
            AuthBox(
              child: Column(
                children: [
                  // Cuisines Header
                  _buildSectionHeader("My Cuisines", () => _addItem(_cuisineControllers)),
                  
                  if (_cuisineControllers.isEmpty) 
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text("No cuisines added yet.", style: TextStyle(color: Colors.grey)),
                    ),
                    
                  ..._cuisineControllers.asMap().entries.map((entry) {
                    return Row(
                      children: [
                        Expanded(
                          child: AuthTextField(
                            labelText: "Cuisine",
                            obscureText: false,
                            controller: entry.value,
                            prefixIcon: const Icon(Icons.restaurant, size: 18),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                          onPressed: () => _removeItem(_cuisineControllers, entry.key),
                        ),
                      ],
                    );
                  }),

                  const Divider(height: 30),

                  // Dietary Header
                  _buildSectionHeader("Dietary Restrictions", () => _addItem(_dietaryControllers)),

                  if (_dietaryControllers.isEmpty) 
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text("No restrictions.", style: TextStyle(color: Colors.grey)),
                    ),

                  ..._dietaryControllers.asMap().entries.map((entry) {
                    return Row(
                      children: [
                        Expanded(
                          child: AuthTextField(
                            labelText: "Restriction",
                            obscureText: false,
                            controller: entry.value,
                            prefixIcon: const Icon(Icons.warning_amber_rounded, size: 18),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                          onPressed: () => _removeItem(_dietaryControllers, entry.key),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // --- 4. Actions ---
            
            // Change Password (Secondary Action)
            SizedBox(
              width: double.infinity,
              height: 55,
              child: OutlinedButton(
                onPressed: () => Navigator.pushNamed(context, '/change_password'),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey.shade400),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text("Change Password", style: TextStyle(color: Colors.black87, fontSize: 16)),
              ),
            ),
            
            const SizedBox(height: 15),

            // Save Changes (Primary Action)
            AuthButton(
              text: "Save Changes",
              onPressed: () {
                setState(() => _isEditingUsername = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Settings Saved!'), backgroundColor: Colors.green),
                );
              },
            ),

            const SizedBox(height: 30),

            // Delete Account (Danger Zone)
            TextButton(
              onPressed: _handleDeleteAccount,
              child: const Text(
                "Delete Account",
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14),
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