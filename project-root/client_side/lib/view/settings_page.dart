import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; 

// [IMPORT] Local Widgets, Navigation & VM
import 'common_widgets.dart'; 
import 'bottom_nav.dart';
import '../viewmodels/settings_page_vm.dart'; 

/// **SettingsPage**
/// ----------------------------------------------------------------------------
/// **Overview:**
/// The user profile management screen. 
///
/// **Navigation Logic:**
/// * **Index 0 (Create Room):** BLOCKED. Shows a red `SnackBar` popup.
/// * **Index 1 (Home):** ALLOWED. Navigates back to Dashboard.
/// * **Index 2 (Settings):** ACTIVE. Current page.
/// ----------------------------------------------------------------------------
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // ===========================================================================
  // STATE & CONTROLLERS
  // ===========================================================================
  
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController(); 
  final FocusNode _usernameFocusNode = FocusNode();

  bool _isEditingUsername = false;

  // ===========================================================================
  // LIFECYCLE
  // ===========================================================================

  @override
  void initState() {
    super.initState();
    // Fetch initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchUserData();
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _usernameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    final vm = Provider.of<SettingsViewModel>(context, listen: false);
    await vm.loadCurrentUser();
    
    if (mounted && vm.currentUser != null) {
      setState(() {
        _usernameController.text = vm.currentUser!.username;
        _emailController.text = vm.currentUser!.email;
      });
    }
  }

  // ===========================================================================
  // UI HELPERS (SnackBar)
  // ===========================================================================

  /// Displays a floating SnackBar exactly like in `home.dart`.
  /// Used for success messages and blocking errors.
  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: isError ? const Duration(seconds: 4) : const Duration(seconds: 2),
      ),
    );
  }

  // ===========================================================================
  // UI HANDLERS
  // ===========================================================================

  void _handleSave() async {
    final vm = Provider.of<SettingsViewModel>(context, listen: false);
    FocusScope.of(context).unfocus(); 

    final success = await vm.updateProfile(username: _usernameController.text);

    if (!mounted) return;

    if (success) {
      setState(() => _isEditingUsername = false);
      _showSnackBar('Settings Saved Successfully!', isError: false);
    } else {
      _showSnackBar(vm.errorMessage ?? 'Update failed', isError: true);
    }
  }

  void _handlePasswordReset() async {
    final vm = Provider.of<SettingsViewModel>(context, listen: false);
    await vm.resetPassword();

    if (!mounted) return;

    if (vm.errorMessage == null) {
      _showSnackBar('Reset email sent to ${_emailController.text}', isError: false);
    } else {
      _showSnackBar(vm.errorMessage!, isError: true);
    }
  }

  void _handleDeleteAccount() {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text("Delete Account?"),
          content: const Text("This action cannot be undone."),
          actions: [
            TextButton(child: const Text("Cancel"), onPressed: () => Navigator.of(ctx).pop()),
            TextButton(
              child: const Text("Delete", style: TextStyle(color: Colors.red)),
              onPressed: () async {
                Navigator.of(ctx).pop(); 
                final vm = Provider.of<SettingsViewModel>(context, listen: false);
                final success = await vm.deleteAccount();
                if (success && mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _handleLogout() {
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  /// **_handleBottomNavTap**
  /// 
  /// Intercepts navigation taps to enforce logic specific to the Settings Page.
  ///
  /// * **Index 0 (Create Room):** BLOCKED. Triggers the Red SnackBar.
  /// * **Index 1 (Home):** ALLOWED. Navigates to Home.
  /// * **Index 2 (Settings):** IGNORED. (Current Page).
  void _handleBottomNavTap(int index) {
    if (index == 1) {
      // Index 1 = Home. Allow navigation.
      Navigator.pushReplacementNamed(context, '/home');
    } else if (index == 0) {
      // Index 0 = Create Room. BLOCK and SHOW SNACKBAR.
      final vm = context.read<SettingsViewModel>();
      
      // 1. Set the specific error message in VM
      vm.showCreateRoomBlockedMessage();
      
      // 2. Show the popup immediately using the helper
      if (vm.errorMessage != null) {
        _showSnackBar(vm.errorMessage!, isError: true);
      }
    }
    // Index 2 is Settings, do nothing.
  }

  // ===========================================================================
  // UI BUILDERS
  // ===========================================================================

  Widget _buildStyledTextField({
    required String labelText,
    required TextEditingController controller,
    required IconData prefixIcon,
    bool readOnly = false,
    FocusNode? focusNode,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        readOnly: readOnly,
        decoration: InputDecoration(
          labelText: labelText,
          prefixIcon: Icon(prefixIcon, color: kPrimaryColor),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
      ),
    );
  }

  Widget _buildChipSection(
    List<String> options,
    List<String> selectedValues,
    Function(String) onToggle,
  ) {
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: options.map((option) {
        final bool isSelected = selectedValues.contains(option);
        return FilterChip(
          label: Text(option),
          selected: isSelected,
          onSelected: (_) => onToggle(option),
          selectedColor: kPrimaryColor.withOpacity(0.2),
          checkmarkColor: kPrimaryColor,
          labelStyle: TextStyle(
            color: isSelected ? kPrimaryColor : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: isSelected ? kPrimaryColor : Colors.grey.shade300),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAvatarSection() {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: const CircleAvatar(
          radius: 50,
          backgroundColor: Colors.white,
          child: Icon(Icons.person, size: 50, color: Colors.grey),
        ),
      ),
    );
  }

  // ===========================================================================
  // MAIN BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SettingsViewModel>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("Settings", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: vm.isLoading 
          ? const Center(child: CircularProgressIndicator(color: kPrimaryColor)) 
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  _buildAvatarSection(),
                  const SizedBox(height: 25),

                  // --- Identity Section ---
                  AuthBox(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Identity", style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 15),
                        _buildStyledTextField(
                          labelText: "Username (Click pen to edit)",
                          controller: _usernameController,
                          focusNode: _usernameFocusNode,
                          readOnly: !_isEditingUsername,
                          prefixIcon: Icons.person_outline,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isEditingUsername ? Icons.check_circle : Icons.edit,
                              color: _isEditingUsername ? Colors.green : Colors.grey,
                            ),
                            onPressed: () {
                              setState(() => _isEditingUsername = !_isEditingUsername);
                              if (_isEditingUsername) _usernameFocusNode.requestFocus();
                            },
                          ),
                        ),
                        const SizedBox(height: 15),
                        _buildStyledTextField(
                          labelText: "Email (Fixed)",
                          controller: _emailController,
                          readOnly: true,
                          prefixIcon: Icons.email_outlined,
                          suffixIcon: const Icon(Icons.lock, size: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // --- Taste Profile Section ---
                  AuthBox(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader("Preferred Cuisines"),
                        _buildChipSection(
                          SettingsViewModel.availableCuisines, 
                          vm.selectedCuisines, 
                          (val) => vm.toggleCuisine(val),
                        ),

                        const Divider(height: 30),

                        _buildSectionHeader("Dietary Restrictions"),
                        _buildChipSection(
                          SettingsViewModel.availableDietary, 
                          vm.selectedDietary, 
                          (val) => vm.toggleDietary(val),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // --- Actions Header ---
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Text("Actions", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ),

                  // --- Save & Reset Buttons ---
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: OutlinedButton(
                      onPressed: vm.isLoading ? null : _handlePasswordReset,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade400),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: const Text("Reset Password via Email", style: TextStyle(color: Colors.black87, fontSize: 16)),
                    ),
                  ),
                  
                  const SizedBox(height: 15),

                  AuthButton(
                    text: "Save Changes",
                    onPressed: vm.isLoading ? null : _handleSave,
                  ),

                  const SizedBox(height: 30),

                  // --- Danger Zone ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: vm.isLoading ? null : _handleDeleteAccount,
                        child: const Text("Delete Account", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ),
                      const Text("|", style: TextStyle(color: Colors.grey)),
                      TextButton(
                        onPressed: _handleLogout,
                        child: const Text("Log Out", style: TextStyle(color: Colors.black87)),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
      
      // --- BOTTOM NAVIGATION ---
      // We pass `_handleBottomNavTap` to override the default behavior
      // specifically for Index 0 (Block) and Index 1 (Allow).
      bottomNavigationBar: CustomBottomNav(
        currentIndex: 2, 
        onTap: _handleBottomNavTap, 
      ),
    );
  }
}