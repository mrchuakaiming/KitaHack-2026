import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// [IMPORT] Business Logic & Services
import '../coordinators/coordinator.dart';
import '../models/user.dart';
import '../services/firestore_service.dart';
import '../services/analytics_service.dart';

/// **SettingsViewModel**
/// ----------------------------------------------------------------------------
/// **Role:**
/// Manages the state, data fetching, and UI logic for the [SettingsPage].
///
/// **Responsibilities:**
/// 1.  **Data Management:** Fetches and holds the current [UserModel].
/// 2.  **State Management:** Handles local edits (Cuisines/Dietary) before saving.
/// 3.  **Action Delegation:** Calls [Coordinator] for updates, resets, and deletions.
/// 4.  **UI Feedback:** Manages `_errorMessage` for SnackBars.
/// ----------------------------------------------------------------------------
class SettingsViewModel extends ChangeNotifier {
  
  // ====================================================================
  // CONSTANTS (Configuration)
  // ====================================================================
  
  static const List<String> availableCuisines = [
    'American', 'Arab', 'Chinese', 'French', 'Indian', 
    'Indonesian', 'Italian', 'Japanese', 'Korean', 'Malay', 'Mamak',
    'Mediterranean', 'Mexican', 'Nyonya', 'Thai',
    'Vietnamese', 'Western'
  ];

  static const List<String> availableDietary = [
  'Dairy-Free',
  'Gluten-Free',
  'Halal',
  'Kosher',
  'Low-Carb',
  'Nut-Free',
  'Seafood',
  'Vegan'
  ];

  // ====================================================================
  // DEPENDENCIES
  // ====================================================================
  final Coordinator _coordinator;
  final FirestoreService _firestore;

  // ====================================================================
  // STATE PROPERTIES
  // ====================================================================
  
  bool _isLoading = false;
  String? _errorMessage;
  UserModel? _currentUser;

  // -- Local Selection State (Temporary buffers) --
  final Set<String> _selectedCuisines = {};
  final Set<String> _selectedDietary = {};

  // ====================================================================
  // CONSTRUCTOR
  // ====================================================================
  
  SettingsViewModel({
    Coordinator? coordinator, 
    FirestoreService? firestore
  }) : _coordinator = coordinator ?? Coordinator(),
       _firestore = firestore ?? FirestoreService();

  // ====================================================================
  // GETTERS
  // ====================================================================
  
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  UserModel? get currentUser => _currentUser;
  
  List<String> get selectedCuisines => _selectedCuisines.toList();
  List<String> get selectedDietary => _selectedDietary.toList();

  // ====================================================================
  // 0. LOAD DATA
  // ====================================================================

  /// Fetches the user profile and syncs local state.
  Future<void> loadCurrentUser() async {
    _setLoading(true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        _currentUser = await _firestore.getUser(uid);
        
        if (_currentUser != null) {
          _selectedCuisines.clear();
          _selectedCuisines.addAll(_currentUser!.preferredCuisine);
          
          _selectedDietary.clear();
          _selectedDietary.addAll(_currentUser!.dietaryRestrictions);
        }
      }
    } catch (e) {
      _errorMessage = "Failed to load profile: $e";
    } finally {
      _setLoading(false);
    }
  }

  // ====================================================================
  // 1. TOGGLE SELECTIONS
  // ====================================================================

  void toggleCuisine(String cuisine) {
    if (_selectedCuisines.contains(cuisine)) {
      _selectedCuisines.remove(cuisine);
    } else {
      _selectedCuisines.add(cuisine);
    }
    notifyListeners();
  }

  void toggleDietary(String restriction) {
    if (_selectedDietary.contains(restriction)) {
      _selectedDietary.remove(restriction);
    } else {
      _selectedDietary.add(restriction);
    }
    notifyListeners();
  }

  // ====================================================================
  // 2. UPDATE PROFILE
  // ====================================================================

  Future<bool> updateProfile({required String username}) async {
    _setLoading(true);
    _clearError();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _errorMessage = "You must be logged in.";
      _setLoading(false);
      return false;
    }

    try {
      final updatedModel = UserModel(
        uid: user.uid,
        email: user.email ?? '', 
        username: username.trim(),
        preferredCuisine: _selectedCuisines.toList(),
        dietaryRestrictions: _selectedDietary.toList(),
        hostedRooms: _currentUser?.hostedRooms ?? [],
      );

      await _coordinator.updateProfile(updated: updatedModel);
      _currentUser = updatedModel;

      await AnalyticsService().logEvent('profile_update', params: {
        'cuisine_count': _selectedCuisines.length,
      });

      _setLoading(false);
      return true;

    } catch (e) {
      _errorMessage = "Update failed: $e";
      _setLoading(false);
      return false;
    }
  }

  // ====================================================================
  // 3. ACCOUNT ACTIONS
  // ====================================================================

  Future<void> resetPassword() async {
    _setLoading(true);
    _clearError();
    try {
      final email = FirebaseAuth.instance.currentUser?.email;
      if (email != null) {
        await _coordinator.resetPassword(email);
      } else {
        _errorMessage = "No email found.";
      }
    } catch (e) {
      _errorMessage = "Reset failed: $e";
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteAccount() async {
    _setLoading(true);
    try {
      await _coordinator.deleteAccount();
      return true; 
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  // ====================================================================
  // 4. NAVIGATION BLOCKING LOGIC (UI Helper)
  // ====================================================================

  /// **showCreateRoomBlockedMessage**
  /// 
  /// Sets the internal error message string when the user attempts to 
  /// create a room from the Settings page. This string is then read by the UI
  /// to display the SnackBar.
  void showCreateRoomBlockedMessage() {
    _errorMessage = "Restricted: Please return to the Home page using the HOME button to create a room.";
    // We notify listeners so the UI can read 'errorMessage' immediately
    notifyListeners();
  }

  // ====================================================================
  // HELPERS
  // ====================================================================

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}