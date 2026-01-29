import 'package:flutter/material.dart';

class RoomViewModel extends ChangeNotifier {
  String _roomId = "Unknown";
  // removed _roomName
  
  bool _isHost = false;
  
  // Lobby State
  RangeValues _budgetRange = const RangeValues(10, 50);
  final List<String> _preferences = [];
  bool _isLocked = false;
  bool _isLoading = false;

  String get roomId => _roomId;
  // removed get roomName

  bool get isHost => _isHost;
  RangeValues get budgetRange => _budgetRange;
  List<String> get preferences => List.unmodifiable(_preferences);
  bool get isLocked => _isLocked;
  bool get isLoading => _isLoading;

  // --- ACTIONS ---

  Future<String?> createRoom() async {
    _setLoading(true);
    await Future.delayed(const Duration(seconds: 1)); 
    
    // Generate ID internally or accept one passed from Home
    String newId = "R${DateTime.now().millisecond}X";
    
    _roomId = newId;
    _isHost = true;
    _resetLobby();
    
    _setLoading(false);
    return newId;
  }

  Future<bool> joinRoom(String code) async {
    _setLoading(true);
    await Future.delayed(const Duration(seconds: 1)); 
    
    _roomId = code;
    _isHost = false;
    _resetLobby();
    
    _setLoading(false);
    return true;
  }
  
  // (Lobby Interactions remain exactly the same as before...)
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