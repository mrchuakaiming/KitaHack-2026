import 'package:flutter/material.dart';

// TODO: searchRestaurant(), submitPreferences(), leaveRoom(), geenerateRecommendation(), storeRecommendation(), getRecommendation(), wantResult() from coordinator.dart

/// The ViewModel responsible for the Active Room (Lobby) state.
class RoomViewModel extends ChangeNotifier {
  
  // --- STATE ---
  String _roomId = "";
  
  // Host Status: Determines who sees the "Generate" button vs "Save" button
  bool _isHost = false; 
  
  // Lobby State
  RangeValues _budgetRange = const RangeValues(10, 500);
  final List<String> _preferences = [];
  
  // Participant State: Local user has finished voting
  bool _isLocked = false;
  
  // Host State: Tracks if all other users have finished voting
  // This controls the Host's button color (Grey -> Green)
  bool _allParticipantsReady = false; 
  
  bool _isLoading = false;
  
  // Result State
  Map<String, dynamic>? _recommendation; 

  // --- GETTERS ---
  String get roomId => _roomId;
  bool get isHost => _isHost;
  RangeValues get budgetRange => _budgetRange;
  List<String> get preferences => List.unmodifiable(_preferences);
  bool get isLocked => _isLocked;
  bool get allParticipantsReady => _allParticipantsReady; // NEW
  bool get isLoading => _isLoading;
  Map<String, dynamic>? get recommendation => _recommendation;

  // --- 1. INITIALIZATION ---

  Future<void> joinRoom(String code) async {
    _setLoading(true);
    _roomId = code;
    
    // TODO: Real logic to check if user is Host
    // SIMULATION: If code contains "HOST", we act as Host for testing.
    // Otherwise, acts as Participant.
    _isHost = code.toUpperCase().contains("HOST"); 
    
    _resetLobby();
    
    // SIMULATION: If we are host, simulate other users finishing after 5 seconds
    if (_isHost) {
      simulateParticipantsFinishing();
    }

    _setLoading(false);
  }

  // --- 2. USER ACTIONS ---

  Future<List<String>> searchRestaurant(String query) async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (query.isEmpty) return [];
    return ["$query Place A", "$query Place B", "The Best $query"];
  }

  void addPreference(String item) {
    if (_isLocked) return;
    if (!_preferences.contains(item)) {
      _preferences.add(item);
      notifyListeners();
    }
  }

  /// PARTICIPANT: Save Preferences
  /// Locks the UI and sends votes to DB.
  Future<void> submitPreferences() async {
    _setLoading(true);
    
    // TODO: Call RoomService.submitUserVotes()
    await Future.delayed(const Duration(seconds: 1));
    
    _isLocked = true; // This triggers the button change to Grey/Non-clickable
    _setLoading(false);
  }

  Future<void> leaveRoom() async {
    _setLoading(true);
    await Future.delayed(const Duration(milliseconds: 500));
    _resetLobby();
    _roomId = "Unknown";
    _setLoading(false);
  }

  // --- 3. HOST ACTIONS ---

  /// Simulates waiting for other users to click "Save Preferences".
  /// In a real app, this would be a Stream listener from Firestore/Socket.
  void simulateParticipantsFinishing() async {
    await Future.delayed(const Duration(seconds: 5));
    _allParticipantsReady = true; // This triggers Host button Grey -> Green
    notifyListeners();
  }

  /// HOST: Generate Result
  /// Only allowed if [_allParticipantsReady] is true.
  Future<void> generateRecommendation() async {
    if (!_isHost) return; 

    _setLoading(true);
    await Future.delayed(const Duration(seconds: 2));

    if (_preferences.isNotEmpty) {
      _recommendation = {
        'name': _preferences[0],
        'type': 'User Choice',
        'timestamp': DateTime.now().toString(),
      };
    } else {
      _recommendation = {
        'name': "Random Place Nearby",
        'type': 'Fallback',
        'timestamp': DateTime.now().toString(),
      };
    }

    await storeRecommendation(_recommendation!);
    _setLoading(false);
  }

  Future<void> storeRecommendation(Map<String, dynamic> result) async {
    await Future.delayed(const Duration(milliseconds: 500));
    notifyListeners();
  }

  // --- 4. RESULT RETRIEVAL ---

  Future<void> wantResult() async {
    await Future.delayed(const Duration(seconds: 1));
    notifyListeners();
  }

  // --- LOCAL HELPERS ---
  
  void setBudget(RangeValues values) {
    if (!_isLocked) {
      _budgetRange = values;
      notifyListeners();
    }
  }

  void removePreference(String pref) {
    if (!_isLocked) {
      _preferences.remove(pref);
      notifyListeners();
    }
  }

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }

  void _resetLobby() {
    _budgetRange = const RangeValues(10, 50);
    _preferences.clear();
    _isLocked = false;
    _allParticipantsReady = false; // Reset host wait state
    _recommendation = null;
  }

  /// Bridge method for the View to call
  void lockSelection() {
    submitPreferences();
  }
}