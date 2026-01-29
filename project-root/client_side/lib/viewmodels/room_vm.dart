import 'package:flutter/material.dart';

class RoomViewModel extends ChangeNotifier {
  // ... (Previous State variables remain the same) ...
  String _roomId = "Unknown";
  String _roomName = "Loading...";
  bool _isHost = false;
  
  // Lobby State
  RangeValues _budgetRange = const RangeValues(10, 50);
  final List<String> _preferences = [];
  bool _isLocked = false;
  bool _isLoading = false;

  // Getters
  String get roomId => _roomId;
  String get roomName => _roomName;
  bool get isHost => _isHost;
  RangeValues get budgetRange => _budgetRange;
  List<String> get preferences => List.unmodifiable(_preferences);
  bool get isLocked => _isLocked;
  bool get isLoading => _isLoading;

  // --- ACTIONS ---

  // UPDATED: Returns String (The new Room ID) instead of bool
  Future<String?> createRoom(String name) async {
    _setLoading(true);
    await Future.delayed(const Duration(seconds: 1)); 
    
    // Generate ID
    String newId = "R${DateTime.now().millisecond}X";
    
    _roomId = newId;
    _roomName = name;
    _isHost = true;
    _resetLobby();
    
    _setLoading(false);
    return newId; // Return the ID to the UI
  }

  // (joinRoom and other methods remain the same as before)
  Future<bool> joinRoom(String code) async {
    _setLoading(true);
    await Future.delayed(const Duration(seconds: 1));
    _roomId = code;
    _roomName = "Joined Room"; 
    _isHost = false;
    _resetLobby();
    _setLoading(false);
    return true;
  }
  
  // Lobby Interactions
  void setBudget(RangeValues values) {
    if (!_isLocked) {
      _budgetRange = values;
      notifyListeners();
    }
  }

  void addPreference(String pref) {
    if (!_isLocked) {
      _preferences.add(pref);
      notifyListeners();
    }
  }

  void removePreference(String pref) {
    if (!_isLocked) {
      _preferences.remove(pref);
      notifyListeners();
    }
  }

  void lockSelection() {
    _isLocked = true;
    notifyListeners();
  }

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }

  void _resetLobby() {
    _budgetRange = const RangeValues(10, 50);
    _preferences.clear();
    _isLocked = false;
  }
}