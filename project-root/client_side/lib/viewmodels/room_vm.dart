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
import '../models/user.dart'; // Needed to fetch the User profile for usernames
import '../services/firestore_service.dart';

/// ==============================================================================
/// ROOM VIEW MODEL (Presenter/Controller)
/// ==============================================================================
/// The RoomViewModel orchestrates the state and business logic for the RoomPage.
/// It bridges the gap between the local UI state and the backend Firebase ecosystem
/// (Firestore for persistent room state, Realtime Database for active participant tracking).
class RoomViewModel extends ChangeNotifier {
  final Coordinator _coordinator;
  final FirestoreService _firestore;

  /// The absolute limit on how many preferences a single user can add.
  static const int MAX_PREFS = 3;

  // ===========================================================================
  // 1. STATE VARIABLES
  // ===========================================================================
  String _roomId = "";
  bool _isLoading = true;
  bool _isHost = false;
  
  /// Internal state tracking if the current user has successfully synced their votes to the database.
  /// When true, it locks the UI to prevent further tampering.
  bool _isLockedState = false; 
  String? _errorMessage;
  
  /// Stores the UID of the creator to identify them among participants for UI styling.
  String _hostUid = "";

  // ===========================================================================
  // 2. DATA VARIABLES
  // ===========================================================================
  int _submittedCount = 0; 
  Map<String, dynamic>? _recommendation; 
  List<Map<String, dynamic>> _collectedParticipants = [];

  /// A curated list mapping UIDs to their fetched Usernames and Roles. 
  /// This is bound directly to the UI Chip list.
  List<Map<String, dynamic>> _submittedUsers = [];
  
  /// A local memory map to prevent re-fetching the same user document multiple times 
  /// during Realtime Database stream events.
  final Map<String, String> _userNamesCache = {};

  // ===========================================================================
  // 3. LOCAL SELECTION STATE
  // ===========================================================================
  final List<Map<String, dynamic>> _selectedRestaurants = [];
  final Set<String> _selectedCuisines = {};
  RangeValues _budgetRange = const RangeValues(10, 50);

  /// Maintains the listener for the Realtime DB node, ensuring it can be disposed cleanly.
  StreamSubscription? _participantsSubscription;

  RoomViewModel({Coordinator? coordinator, FirestoreService? db})
      : _coordinator = coordinator ?? Coordinator(),
        _firestore = db ?? FirestoreService();

  // ===========================================================================
  // 4. PUBLIC GETTERS (Read-only access for the UI)
  // ===========================================================================
  String get roomId => _roomId;
  bool get isLoading => _isLoading;
  bool get isHost => _isHost;
  
  /// Reflects if the user (Host or Guest) is locked into their submission.
  /// Disables the budget slider and live preference buttons upon submission.
  bool get isLocked => _isLockedState;
  
  /// Accurately tracks if the user's vote is in the database.
  bool get hasSubmitted => _isLockedState;
  
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get recommendation => _recommendation;
  int get submittedCount => _submittedCount;
  
  /// The curated list of submitted users containing their actual Usernames.
  List<Map<String, dynamic>> get submittedUsers => _submittedUsers;
  
  List<Map<String, dynamic>> get selectedRestaurants => _selectedRestaurants;
  RangeValues get budgetRange => _budgetRange;
  
  /// A merged list of both cuisines and restaurant names for UI rendering.
  List<String> get allPreferences => [
        ..._selectedCuisines,
        ..._selectedRestaurants.map((r) => r['name'] as String),
      ];
      
  int get preferenceCount => _selectedCuisines.length + _selectedRestaurants.length;

  /// ==========================================================================
  /// INITIALIZATION
  /// ==========================================================================
  /// Called immediately when the RoomPage loads. Sets up the initial state,
  /// registers the user with the server, and establishes database listeners.
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

      // Fetch the room document to identify the Host UID for UI highlighting
      final roomData = await _firestore.getRoom(roomId);
      if (roomData != null) {
        _hostUid = roomData['host_uid'] ?? "";
      }

      // Registers the user with the backend, which returns their role (host/guest)
      final status = await _coordinator.joinRoom(roomId: roomId, uid: uid);
      _isHost = (status == 'host');
      _isLockedState = (status == 'done_user'); 

      await _coordinator.leaveRoom(roomId: roomId, uid: uid);
      
      // Checks if the AI has already generated a response for this room
      await _fetchExistingResult();
      
      // Starts listening for dynamic changes (people joining/submitting)
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

  /// Wipes all unsubmitted UI states to ensure a clean slate.
  void clearLocalPreferences() {
    _selectedRestaurants.clear();
    _selectedCuisines.clear();
    _budgetRange = const RangeValues(10, 50); 
    notifyListeners();
  }

  /// Updates the slider values dynamically unless the user is locked.
  void updateBudget(RangeValues newValues) {
    if (isLocked) return;
    _budgetRange = newValues;
    notifyListeners();
  }

  /// Queries the backend to see if the Gemini recommendation is already complete.
  Future<void> _fetchExistingResult() async {
    try {
      final result = await _coordinator.wantResult(roomId: _roomId);
      if (result.isNotEmpty) {
        _recommendation = result;
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Designed to be hooked into a StreamBuilder (in room.dart) to catch live Document updates.
  void updateFromStream(Map<String, dynamic> data) {
    if (data.containsKey('output')) {
      final output = data['output'];
      if (output is Map && output.isNotEmpty) {
        _recommendation = Map<String, dynamic>.from(output);
      }
    }
  }

  /// ==========================================================================
  /// REALTIME DATABASE LISTENERS & USERNAME HYDRATION
  /// ==========================================================================
  /// Initiates a persistent connection to the Firebase Realtime Database
  /// to track the 'participants' node for live updates.
  void _subscribeToParticipants() {
    final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? "";

    _participantsSubscription?.cancel();
    _participantsSubscription = FirebaseDatabase.instance
        .ref("participants/$_roomId")
        .onValue
        .listen((event) {
          final data = event.snapshot.value as Map<dynamic, dynamic>?;
          _processRTDBData(data, currentUid);
        });
  }

  /// Manual trigger to force-fetch the RTDB state.
  Future<void> _refreshParticipantCount() async {
    final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? "";
    try {
      final snapshot = await FirebaseDatabase.instance.ref("participants/$_roomId").get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        _processRTDBData(data, currentUid);
      }
    } catch (_) {}
  }

  /// Master processor for participant updates. 
  /// Because RTDB only holds UIDs, this function dynamically queries Firestore 
  /// to map those UIDs to real Usernames for a better UI experience.
  Future<void> _processRTDBData(Map<dynamic, dynamic>? data, String currentUid) async {
    // If the room data is completely empty/deleted
    if (data == null) {
      _submittedCount = 0;
      _collectedParticipants = [];
      _isLockedState = false;
      _submittedUsers = [];
      notifyListeners();
      return;
    }

    final List<Map<String, dynamic>> temp = [];
    int count = 0;
    bool currentUserSubmitted = false;
    List<String> uidsToFetch = [];
    List<Map<String, dynamic>> newSubmittedUsers = [];

    // Parse the incoming generic data block
    data.forEach((uidKey, details) {
      final uid = uidKey as String;
      if (details is Map && details['submitted'] == true) {
        count++;
        if (uid == currentUid) currentUserSubmitted = true;
        
        try {
           temp.add(Map<String, dynamic>.from(details));
        } catch(e) { debugPrint(e.toString()); }

        // Cache-check for Username: If we don't know it, tag it for fetching.
        if (!_userNamesCache.containsKey(uid)) {
          uidsToFetch.add(uid);
          _userNamesCache[uid] = "Loading..."; 
        }

        // Build the basic UI object using the cache (it may say "Loading..." temporarily)
        newSubmittedUsers.add({
          'uid': uid,
          'username': _userNamesCache[uid],
          'isHost': uid == _hostUid,
        });
      }
    });

    // UX Enhancement: Sort the array so the Host always appears first in the UI chip list
    newSubmittedUsers.sort((a, b) {
      if (a['isHost'] && !b['isHost']) return -1;
      if (!a['isHost'] && b['isHost']) return 1;
      return 0;
    });

    // Update state with parsed data
    _submittedCount = count;
    _collectedParticipants = temp;
    _isLockedState = currentUserSubmitted;
    _submittedUsers = newSubmittedUsers;
    notifyListeners();

    // Secondary Operation: Perform Async fetch for any *new* users detected in the stream
    if (uidsToFetch.isNotEmpty) {
      bool fetchedNew = false;
      for (String u in uidsToFetch) {
        try {
          final userProfile = await _firestore.getUser(u); 
          if (userProfile != null && userProfile.username.isNotEmpty) {
            _userNamesCache[u] = userProfile.username; // Save successful lookup to cache
          } else {
            _userNamesCache[u] = (u == _hostUid) ? "Host" : "Guest"; // Fallback text
          }
          fetchedNew = true;
        } catch (e) {
          _userNamesCache[u] = (u == _hostUid) ? "Host" : "Guest"; // Fallback on error
          fetchedNew = true;
        }
      }
      
      // If we learned new names, stitch them into the UI array and force a re-render
      if (fetchedNew) {
        for (var userMap in _submittedUsers) {
          userMap['username'] = _userNamesCache[userMap['uid']];
        }
        notifyListeners();
      }
    }
  }

  /// ==========================================================================
  /// UI ACTIONS & VALIDATION
  /// ==========================================================================
  /// Acts as the gatekeeper for the bottom navigation bar to prevent accidental exits.
  bool validateNavigation(int index) {
    // 1. Allow staying on the current tab (Assuming index 1 is the Room tab)
    if (index == 1) { 
      _errorMessage = null; 
      return true; 
    }

    // 2. If the AI recommendation is already generated, the event is over. Free to leave.
    if (_recommendation != null) {
      _errorMessage = null;
      return true;
    }

    // 3. If the user (Host or Guest) has successfully submitted their preferences, they can leave freely.
    if (_isLockedState) {
      _errorMessage = null;
      return true;
    }

    // 4. If we reach here, the user HAS NOT submitted yet. Block navigation and surface the warning.
    _errorMessage = "Please submit your preferences before leaving the room.";
    notifyListeners();
    return false;
  }

  /// Proxies the Google Places query to the backend Cloud Run service to bypass web CORS limitations.
  Future<List<Map<String, dynamic>>> searchPlaces(String query) async {
    try { 
      return await _coordinator.searchRestaurant(query); 
    } catch (_) { 
      return []; 
    }
  }

  /// Validates and adds a restaurant to local state.
  bool addRestaurant(Map<String, dynamic> place) {
    if (isLocked || preferenceCount >= MAX_PREFS) return false;
    
    // Prevents duplicate additions
    if (!_selectedRestaurants.any((r) => r['placeId'] == place['placeId'])) {
      _selectedRestaurants.add(place);
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Validates and adds a cuisine type to local state.
  bool addCuisine(String cuisine) {
    if (isLocked || preferenceCount >= MAX_PREFS) return false;
    _selectedCuisines.add(cuisine);
    notifyListeners();
    return true;
  }

  /// Removes an item by its name, scanning both cuisine and restaurant sets.
  void removePreferenceByName(String name) {
    if (isLocked) return;
    _selectedRestaurants.removeWhere((r) => r['name'] == name);
    _selectedCuisines.remove(name);
    notifyListeners();
  }

  /// ==========================================================================
  /// SUBMISSION LOGIC (HOST & GUEST)
  /// ==========================================================================
  /// Compiles local choices into a standard model and writes them to the backend.
  Future<void> submitPreference() async {
    if (preferenceCount == 0) {
      _errorMessage = "Please add at least one preference!";
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Package the diverse choices into a unified format for the AI Payload
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

      // Execute network call to log preferences
      await _coordinator.submitPreference(
        uid: FirebaseAuth.instance.currentUser!.uid, 
        roomId: _roomId, 
        preferences: prefModel
      );
      
      // Instantly lock the UI upon success and refresh the stream to show the green checkmark
      _isLockedState = true; 
      await _refreshParticipantCount();
      
    } catch (e) {
      _errorMessage = "Submission Failed: $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// ==========================================================================
  /// GENERATION LOGIC (HOST ONLY)
  /// ==========================================================================
  /// Triggers the cloud function that feeds the collected data to the Gemini 2.5 Flash API.
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
      // 1. Update Firestore status so Guests see the "AI is Deciding" global loading screen
      await FirebaseFirestore.instance.collection('rooms').doc(_roomId).update({
        'status': 'processing'
      });

      // 2. Dispatch the execution command to the Singapore server
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
      // Clean up messy exception traces for the UI snackbar
      final errString = e.toString().replaceAll('Exception:', '').trim();
      _errorMessage = "Generation Error: $errString";
      
      // Rollback the status so the Host can attempt generation again
      await FirebaseFirestore.instance.collection('rooms').doc(_roomId).update({
        'status': 'waiting'
      });
    } finally {
      _isLoading = false; 
      notifyListeners();
    }
  }

  /// Cleans up the active Realtime Database listeners to prevent memory leaks 
  /// when the user navigates away from the RoomPage.
  @override
  void dispose() {
    _participantsSubscription?.cancel();
    super.dispose();
  }
}