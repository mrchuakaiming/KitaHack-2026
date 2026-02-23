import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http; 

import '../config.dart'; 
import '../coordinators/coordinator.dart';
import '../models/preferences.dart';
import '../services/firestore_service.dart';

/// ==============================================================================
/// ROOM VIEW MODEL
/// ==============================================================================
/// This class acts as the "Brain" for the Room Page. It bridges the UI with 
/// Firestore, Realtime Database, and the Python AI Backend.
/// 
/// **KEY RESPONSIBILITIES:**
/// 1. **Session Management**: Handles joining, leaving, and identifying Host vs Guest.
/// 2. **State Management**: Tracks if the room is "Locked" (user submitted) or "Processing".
/// 3. **Real-time Sync**: Listens to the Realtime Database to count how many users are ready.
/// 4. **AI Integration**: Sends the gathered data to the Python Cloud Function.
/// ==============================================================================
class RoomViewModel extends ChangeNotifier {
  final Coordinator _coordinator;
  final FirestoreService _firestore;

  /// The hard limit on how many preferences a single user can select.
  static const int MAX_PREFS = 3;

  // --- 1. STATE VARIABLES ---
  
  /// The unique identifier for the current active room.
  String _roomId = "";
  
  /// Controls the loading spinners in the UI during network requests.
  bool _isLoading = true;
  
  /// Determines if the current user created the room. Hosts manage the session but do not vote.
  bool _isHost = false;
  
  /// If true, the user has successfully submitted their choices and the UI is disabled.
  bool _isLocked = false; 
  
  /// Holds any error messages to be displayed via SnackBar in the UI.
  String? _errorMessage;

  // --- 2. DATA VARIABLES ---
  
  /// The count of users who have clicked "Submit". Watched by the Host to know when to start generation.
  int _submittedCount = 0; 
  
  /// The final AI result containing the restaurant name, price range, and justification.
  Map<String, dynamic>? _recommendation; 
  
  /// Raw participant data collected from Realtime Database (used for payload construction).
  List<Map<String, dynamic>> _collectedParticipants = [];

  // --- 3. LOCAL SELECTION STATE ---
  
  /// A temporary list of specific restaurants the user has selected via Google Maps.
  final List<Map<String, dynamic>> _selectedRestaurants = [];
  
  /// A temporary set of general cuisines the user has selected.
  final Set<String> _selectedCuisines = {};
  
  /// The budget bounds selected by the user. Defaults to $10 - $50.
  RangeValues _budgetRange = const RangeValues(10, 50);

  /// Subscription to listen for real-time participant count updates.
  StreamSubscription? _participantsSubscription;

  /// Constructor injects dependencies for easier testing and modularity.
  RoomViewModel({Coordinator? coordinator, FirestoreService? db})
      : _coordinator = coordinator ?? Coordinator(),
        _firestore = db ?? FirestoreService();

  // --- 4. PUBLIC GETTERS ---
  String get roomId => _roomId;
  bool get isLoading => _isLoading;
  bool get isHost => _isHost;
  bool get isLocked => _isLocked;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get recommendation => _recommendation;
  int get submittedCount => _submittedCount;
  
  List<Map<String, dynamic>> get selectedRestaurants => _selectedRestaurants;
  RangeValues get budgetRange => _budgetRange;
  
  /// Returns a merged list of Cuisines and Restaurant Names for rendering the unified UI list.
  List<String> get allPreferences => [
        ..._selectedCuisines,
        ..._selectedRestaurants.map((r) => r['name'] as String),
      ];
      
  /// Current total of selected items across both categories.
  int get preferenceCount => _selectedCuisines.length + _selectedRestaurants.length;

  /// ==========================================================================
  /// INITIALIZATION
  /// ==========================================================================
  /// Called immediately when the Room Page loads.
  /// 
  /// **Logic Flow:**
  /// 1. **Clean Slate**: Calls `clearLocalPreferences()` to wipe stale data.
  /// 2. **Authentication**: Verifies the user is logged in.
  /// 3. **Join Protocol**: Determines if user is Host or Guest.
  /// 4. **Cleanup**: Registers 'onDisconnect' handlers in RTDB.
  /// 5. **Sync**: Starts listening to the participant count stream.
  Future<void> init(String roomId) async {
    _roomId = roomId;
    _isLoading = true;
    _errorMessage = null;
    _recommendation = null; 
    
    clearLocalPreferences();
    notifyListeners();

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? "";
      if (uid.isEmpty) throw Exception("User not authenticated");

      // 1. Join Room and determine authority level
      final status = await _coordinator.joinRoom(roomId: roomId, uid: uid);
      _isHost = (status == 'host');
      _isLocked = (status == 'done_user'); 

      // 2. Register disconnection handlers
      await _coordinator.leaveRoom(roomId: roomId, uid: uid);

      // 3. Fetch pre-existing results (handles users re-joining a finished room)
      await _fetchExistingResult();
      
      // 4. Connect to live presence data
      _subscribeToParticipants();
      await _refreshParticipantCount();

    } catch (e) {
      debugPrint("Room Init Error: $e");
      _errorMessage = "Failed to join room. Please try again.";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// ==========================================================================
  /// LOCAL STATE ACTIONS
  /// ==========================================================================

  /// Clears all temporary selections and resets the budget slider.
  /// Triggered on room entry and when a user chooses to discard unsubmitted changes.
  void clearLocalPreferences() {
    _selectedRestaurants.clear();
    _selectedCuisines.clear();
    _budgetRange = const RangeValues(10, 50); 
    notifyListeners();
  }

  /// **RESTORED METHOD**: Updates the local budget range state.
  /// Triggered by the RangeSlider in `room.dart`.
  /// [newValues] The updated start and end values from the slider.
  void updateBudget(RangeValues newValues) {
    if (_isLocked) return;
    _budgetRange = newValues;
    notifyListeners();
  }

  /// Attempts to fetch a finished recommendation from Firestore.
  /// Silently fails if the room is still active and processing.
  Future<void> _fetchExistingResult() async {
    try {
      final result = await _coordinator.wantResult(roomId: _roomId);
      if (result.isNotEmpty) {
        _recommendation = result;
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Updates local state dynamically when the Firestore StreamBuilder pushes new data.
  /// Extracts the 'output' key which contains the AI payload.
  void updateFromStream(Map<String, dynamic> data) {
    if (data.containsKey('output')) {
      final output = data['output'];
      if (output is Map && output.isNotEmpty) {
        _recommendation = Map<String, dynamic>.from(output);
      }
    }
  }

  /// ==========================================================================
  /// REALTIME DATABASE LISTENERS
  /// ==========================================================================

  /// Listens to `participants/{roomId}` in RTDB.
  /// Parses the raw JSON map, counts users where `submitted == true`, and updates the UI.
  void _subscribeToParticipants() {
    _participantsSubscription?.cancel();
    _participantsSubscription = FirebaseDatabase.instance
        .ref("participants/$_roomId")
        .onValue
        .listen((event) {
          final data = event.snapshot.value as Map<dynamic, dynamic>?;
          if (data != null) {
            final List<Map<String, dynamic>> temp = [];
            int count = 0;
            data.forEach((uid, details) {
              if (details is Map && details['submitted'] == true) {
                count++;
                try {
                   temp.add(Map<String, dynamic>.from(details));
                } catch(e) { print(e); }
              }
            });
            _submittedCount = count;
            _collectedParticipants = temp;
          } else {
            _submittedCount = 0;
            _collectedParticipants = [];
          }
          notifyListeners();
        });
  }

  /// Performs a one-time static read of the RTDB participant count.
  /// Used as a fallback and initializer before the stream fully connects.
  Future<void> _refreshParticipantCount() async {
    try {
      final snapshot = await FirebaseDatabase.instance.ref("participants/$_roomId").get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        int count = 0;
        data.forEach((uid, details) {
          if (details is Map && details['submitted'] == true) count++;
        });
        _submittedCount = count;
        notifyListeners();
      }
    } catch (_) {}
  }

  /// ==========================================================================
  /// UI ACTIONS & VALIDATION
  /// ==========================================================================

  /// Validates if the user is permitted to use the bottom navigation.
  /// Prevents Hosts and Locked users from navigating away without proper teardown.
  bool validateNavigation(int index) {
    if (index == 1) { 
      _errorMessage = null; 
      return true; 
    }
    if (_isHost || _isLocked) {
      _errorMessage = "Please leave the room using the Home button.";
      notifyListeners();
      return false;
    }
    return true;
  }

  /// Proxies Google Maps search queries through the Coordinator to the MapsService.
  Future<List<Map<String, dynamic>>> searchPlaces(String query) async {
    try { 
      return await _coordinator.searchRestaurant(query); 
    } catch (_) { 
      return []; 
    }
  }

  /// Adds a verified Google Maps place object to the local selected restaurants list.
  /// Prevents duplicates based on the Google `placeId`.
  bool addRestaurant(Map<String, dynamic> place) {
    if (_isHost || _isLocked || preferenceCount >= MAX_PREFS) return false;
    
    if (!_selectedRestaurants.any((r) => r['placeId'] == place['placeId'])) {
      _selectedRestaurants.add(place);
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Adds a generic cuisine string to the local selected cuisines set.
  bool addCuisine(String cuisine) {
    if (_isHost || _isLocked || preferenceCount >= MAX_PREFS) return false;
    _selectedCuisines.add(cuisine);
    notifyListeners();
    return true;
  }

  /// Removes a specific preference from either the restaurant list or the cuisine set
  /// based on its string name.
  void removePreferenceByName(String name) {
    if (_isLocked) return;
    _selectedRestaurants.removeWhere((r) => r['name'] == name);
    _selectedCuisines.remove(name);
    notifyListeners();
  }

  /// ==========================================================================
  /// SUBMISSION LOGIC (GUEST)
  /// ==========================================================================
  /// Packages local selections, sends them to Firestore, and marks the user as 
  /// 'submitted' in RTDB, effectively locking their UI.
  Future<void> submitPreference() async {
    if (_isLocked || _isHost) return;
    if (preferenceCount == 0) {
      _errorMessage = "Please add at least one preference!";
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Unify disparate preferences into a single payload array for the AI
      List<Map<String, dynamic>> combinedPrefs = [];
      
      for (var c in _selectedCuisines) {
        combinedPrefs.add({'value': c, 'type': 'cuisine'});
      }
      
      for (var r in _selectedRestaurants) {
        combinedPrefs.add({
          'value': r['name'], 
          'type': 'restaurant', 
          'placeId': r['placeId'], 
          'lat': r['lat'], 
          'lng': r['lng']
        });
      }

      final prefModel = PreferencesModel(
        roomId: _roomId,
        livePreferences: combinedPrefs,
        budget: [_budgetRange.start.round(), _budgetRange.end.round()],
        preferredCuisine: _selectedCuisines.toList(), 
        dietaryRestrictions: [], 
      );

      await _coordinator.submitPreference(
        uid: FirebaseAuth.instance.currentUser!.uid, 
        roomId: _roomId, 
        preferences: prefModel
      );
      
      _isLocked = true; 
      await _refreshParticipantCount();
      
    } catch (e) {
      _errorMessage = "Submission Failed: $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// ==========================================================================
  /// GENERATION LOGIC (HOST)
  /// ==========================================================================
  /// Signals the backend to begin processing the accumulated preferences.
  /// Triggers a UI loading state for all users connected to the Firestore stream.
  Future<void> generateRecommendation() async {
    if (!_isHost) return;

    if (_submittedCount == 0) {
      _errorMessage = "No votes found! Wait for guests to submit.";
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Optimistic Update: Set room status to trigger loading animations across all clients
      await FirebaseFirestore.instance.collection('rooms').doc(_roomId).update({
        'status': 'processing'
      });

      // 2. Transmit gathered Realtime Database data to the Python Cloud Function
      final String backendUrl = "${Config.serverBaseUrl}/ai/generate-outcome";
      
      final response = await http.post(
        Uri.parse(backendUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "roomId": _roomId,
          "participants": _collectedParticipants 
        }),
      );

      if (response.statusCode != 200) {
        throw Exception("Server Error: ${response.body}");
      }
      
    } catch (e) {
      final errString = e.toString().replaceAll('Exception:', '').trim();
      _errorMessage = "Generation Error: $errString";
      
      // Rollback optimistic update on failure to allow retries
      await FirebaseFirestore.instance.collection('rooms').doc(_roomId).update({
        'status': 'waiting'
      });
    } finally {
      _isLoading = false; 
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _participantsSubscription?.cancel();
    super.dispose();
  }
}