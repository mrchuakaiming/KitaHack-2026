import 'package:flutter/material.dart';

class RoomViewModel extends ChangeNotifier {
  // --- STATE ---
  String _roomId = "Unknown";
  bool _isHost = false; // Determined when joining/creating
  
  // Lobby State
  RangeValues _budgetRange = const RangeValues(10, 50);
  final List<String> _preferences = [];
  bool _isLocked = false;
  bool _isLoading = false;
  
  // Result State
  String? _recommendation; // The final result (e.g., "Burger King")

  // --- GETTERS ---
  String get roomId => _roomId;
  bool get isHost => _isHost;
  RangeValues get budgetRange => _budgetRange;
  List<String> get preferences => List.unmodifiable(_preferences);
  bool get isLocked => _isLocked;
  bool get isLoading => _isLoading;
  String? get recommendation => _recommendation;

  // --- 1. INITIALIZATION ---

  Future<void> joinRoom(String code) async {
    _setLoading(true);
    _roomId = code;
    
    // TODO: Call RoomService.getRoomDetails(code)
    // TODO: Check if current userId matches the hostId in DB
    // SIMULATION: Randomly assign host for demo purposes (or set via logic)
    // _isHost = true; 
    
    _resetLobby();
    _setLoading(false);
  }

  // --- 2. USER ACTIONS ---

  /// Search Restaurant (External Service)
  Future<List<String>> searchRestaurant(String query) async {
    // TODO: Call PlacesService.search(query) (Google/Yelp API)
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (query.isEmpty) return [];
    return ["$query Place A", "$query Place B", "The Best $query"];
  }

  /// Add Preference (Local Logic)
  /// Note: Cuisines are hardcoded on device, no service call needed.
  void addPreference(String item) {
    if (_isLocked) return;
    if (!_preferences.contains(item)) {
      _preferences.add(item);
      notifyListeners();
    }
  }

  /// Submit Preferences (Sync to Server)
  Future<void> submitPreferences() async {
    _setLoading(true);
    // TODO: Call RoomService.submitUserVotes(roomId, budget, preferences)
    await Future.delayed(const Duration(seconds: 1));
    _isLocked = true;
    _setLoading(false);
  }

  /// Leave Room (Cleanup)
  Future<void> leaveRoom() async {
    _setLoading(true);
    // TODO: Call RoomService.removeParticipant(roomId, userId)
    await Future.delayed(const Duration(milliseconds: 500));
    _resetLobby();
    _roomId = "Unknown";
    _setLoading(false);
  }

  // --- 3. HOST ACTIONS (Decision Making) ---

  /// Generate Recommendation (Host Only)
  /// Runs the decision algorithm or calls AI service.
  Future<void> generateRecommendation() async {
    if (!_isHost) return; // Security check

    _setLoading(true);

    // TODO: Call RecommendationService.getDecision(roomId)
    // TODO: This service aggregates all user votes and budget ranges
    await Future.delayed(const Duration(seconds: 2));

    // SIMULATION: Pick a random item from preferences
    if (_preferences.isNotEmpty) {
      _recommendation = _preferences[0]; // Simplified logic
    } else {
      _recommendation = "Random Place Nearby";
    }

    // Automatically store it after generation
    await storeRecommendation(_recommendation!);
    
    _setLoading(false);
  }

  /// Store Recommendation (Persist Result)
  Future<void> storeRecommendation(String result) async {
    // TODO: Call RoomService.saveResult(roomId, result)
    // TODO: Trigger a push notification to all users that result is ready
    await Future.delayed(const Duration(milliseconds: 500));
    notifyListeners();
  }

  // --- 4. RESULT RETRIEVAL ---

  /// Want Result (Polling / Listening)
  /// Checks if a decision has been made.
  Future<void> wantResult() async {
    // TODO: Call RoomService.listenForResult(roomId)
    // TODO: In a real app, this would be a Stream, not a Future
    await Future.delayed(const Duration(seconds: 1));
    
    // SIMULATION
    if (_recommendation == null) {
      // If host hasn't decided yet
      // _recommendation = "Waiting for host..."; 
    }
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
    _isHost = false;
    _recommendation = null;
  }

  // ... inside RoomViewModel ...

  /// BRIDGE: Connects UI 'lockSelection' to the backend 'submitPreferences'
  void lockSelection() {
    submitPreferences();
  }

  // ... rest of the class
}