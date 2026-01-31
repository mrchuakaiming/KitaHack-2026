import 'package:flutter/material.dart';

class SettingsViewModel extends ChangeNotifier {
  // --- STATE ---
  bool _isLoading = false;
  String _username = "Loading...";
  String _email = "Loading...";
  
  // Edit Mode State
  bool _isEditing = false;

  // --- GETTERS ---
  bool get isLoading => _isLoading;
  String get username => _username;
  String get email => _email;
  bool get isEditing => _isEditing;

  // --- INITIALIZATION ---

  Future<void> loadProfile() async {
    _setLoading(true);
    
    // TODO: Get current User ID from AuthService
    // TODO: Call UserService.getUserProfile(uid)
    await Future.delayed(const Duration(milliseconds: 500));
    
    // SIMULATION
    _username = "FoodieUser123";
    _email = "user@example.com";
    
    _setLoading(false);
  }

  // --- FUNCTIONS ---

  /// 1. Update Profile (Username, etc.)
  Future<bool> updateProfile(String newUsername) async {
    _setLoading(true);

    // TODO: Call UserService.updateUsername(uid, newUsername)
    await Future.delayed(const Duration(seconds: 1));

    _username = newUsername;
    _isEditing = false; 
    
    _setLoading(false);
    return true;
  }

  /// 2. Clear Data (Delete History/Preferences ONLY)
  Future<bool> clearData() async {
    _setLoading(true);

    // TODO: Call UserService.clearUserHistory(uid)
    await Future.delayed(const Duration(seconds: 2));

    _setLoading(false);
    return true;
  }

  /// 3. Remove Account (Permanent Deletion)
  Future<bool> rmAccount() async {
    _setLoading(true);

    // TODO: Call UserService.deleteUserData(uid)
    // TODO: Call AuthService.deleteUser()
    await Future.delayed(const Duration(seconds: 2));

    _setLoading(false);
    return true; 
  }

  // --- UI HELPERS ---

  void toggleEdit() {
    _isEditing = !_isEditing;
    notifyListeners();
  }

  void logout(BuildContext context) {
    // TODO: Call AuthService.signOut()
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}