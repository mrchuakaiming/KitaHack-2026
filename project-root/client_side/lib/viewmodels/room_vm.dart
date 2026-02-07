import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// [IMPORT] Business Logic & Services
import '../coordinators/coordinator.dart';
import '../models/preferences.dart';
import '../services/firestore_service.dart';
import '../services/analytics_service.dart';

/// **ViewModel for the Active Room Session**
class RoomViewModel extends ChangeNotifier {

  // --- CONSTANTS ---
  static const int maxParticipants = 12; // 1 Host + 11 Guests

  // ====================================================================
  // DEPENDENCIES
  // ====================================================================
  final Coordinator _coordinator;
  final FirestoreService _firestore; 

  // ====================================================================
  // STATE PROPERTIES
  // ====================================================================
  String _roomId = "";
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // Local State
  RangeValues _budgetRange = const RangeValues(20, 50);
  List<String> _localPreferences = [];
  bool _isLocked = false;
  bool _isLoading = false;

  // Remote State
  bool _isHost = false;
  List<PreferencesModel> _participants = [];
  Map<String, dynamic>? _recommendation;
  StreamSubscription? _roomSubscription;

  // ====================================================================
  // CONSTRUCTOR
  // ====================================================================
  RoomViewModel({Coordinator? coordinator, FirestoreService? firestore})
      : _coordinator = coordinator ?? Coordinator(),
        _firestore = firestore ?? FirestoreService();

  // ====================================================================
  // GETTERS
  // ====================================================================
  String get roomId => _roomId;
  RangeValues get budgetRange => _budgetRange;
  List<String> get preferences => List.unmodifiable(_localPreferences);
  bool get isLocked => _isLocked;
  bool get isLoading => _isLoading;
  bool get isHost => _isHost;
  Map<String, dynamic>? get recommendation => _recommendation;
  List<PreferencesModel> get participants => _participants;

  /// Helper: Check if we have participants.
  bool get allParticipantsReady => _participants.isNotEmpty;

  /// Helper: Check if the room has reached its maximum capacity.
  bool get isRoomFull => _participants.length >= maxParticipants;

  /// Returns a warning message if the room is full, or null otherwise.
  String? get roomCapacityWarning {
    if (isRoomFull) {
      return "Maximum capacity ($maxParticipants) reached. No more submissions allowed.";
    }
    return null;
  }

  // ====================================================================
  // 1. INITIALIZATION & STREAMS
  // ====================================================================
  void setRoomId(String id) {
    if (_roomId != id && id.isNotEmpty) {
      _roomId = id;
      _subscribeToRoom();
    }
  }

  void _subscribeToRoom() {
    _roomSubscription?.cancel();
    _roomSubscription = _firestore.streamRoom(_roomId).listen((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return;

      final data = snapshot.data() as Map<String, dynamic>;

      // A. Sync Recommendation
      if (data.containsKey('aiRecommendation')) {
        _recommendation = data['aiRecommendation'];
      }

      // B. Sync Host Status
      if (_uid.isNotEmpty) {
        _isHost = (data['host_uid'] == _uid);
      }

      // C. Sync Participants
      if (data.containsKey('participants')) {
        final rawParticipants = data['participants'] as Map<String, dynamic>;
        _participants = rawParticipants.entries.map((e) {
          if (e.value is Map) {
             return PreferencesModel.fromJson(Map<String, dynamic>.from(e.value));
          }
          return PreferencesModel(roomId: _roomId, livePreferences: [], preferredCuisine: [], budget: [0,0], dietaryRestrictions: []);
        }).toList();
      }

      notifyListeners();
    });
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    super.dispose();
  }

  // ====================================================================
  // 2. USER ACTIONS
  // ====================================================================
  Future<List<Map<String, dynamic>>> searchRestaurant(String query) async {
    if (query.trim().isEmpty) return [];
    return await _coordinator.searchRestaurant(query);
  }

  void addPreference(String item) {
    if (!_isLocked && !_localPreferences.contains(item)) {
      _localPreferences.add(item);
      notifyListeners();
    }
  }

  void removePreference(String item) {
    if (!_isLocked) {
      _localPreferences.remove(item);
      notifyListeners();
    }
  }

  void setBudget(RangeValues range) {
    if (!_isLocked) {
      _budgetRange = range;
      notifyListeners();
    }
  }

  Future<void> submitPreference() async {
    if (_uid.isEmpty || _roomId.isEmpty) return;

    // CAPACITY CHECK
    if (isRoomFull) {
      // If user hasn't submitted yet and room is full, block them.
      // (Unless they are re-submitting, which our current logic treats as new)
      // Ideally check if _uid is already in participants. 
      // For now, simple block:
      if (!_participants.any((p) => true)) { // TODO: Add uid to PreferencesModel to check properly
         // Fail silently or show error via state
         return; 
      }
    }

    _setLoading(true);

    try {
      final prefModel = PreferencesModel(
        roomId: _roomId,
        livePreferences: _localPreferences.map((p) => {'value': p}).toList(),
        budget: [_budgetRange.start.round(), _budgetRange.end.round()],
        preferredCuisine: [], 
        dietaryRestrictions: [],
      );

      await _coordinator.submitPreference(
        uid: _uid,
        roomId: _roomId,
        preferences: prefModel,
      );

      _isLocked = true;
      
      await AnalyticsService().logEvent('preferences_submitted', params: {'room_id': _roomId});

    } catch (e) {
      debugPrint("Submit failed: $e");
      _isLocked = false;
    } finally {
      _setLoading(false);
    }
  }

  void lockSelection() => submitPreference();

  // ====================================================================
  // 3. HOST ACTIONS
  // ====================================================================
  Future<void> generateRecommendation() async {
    if (!_isHost || _roomId.isEmpty) return;

    _setLoading(true);

    try {
      await AnalyticsService().logEvent('ai_generation_started', params: {'room_id': _roomId});

      final result = await _coordinator.generateRecommendation(roomId: _roomId);
      await storeRecommendation(result);

    } catch (e) {
      debugPrint("Generation failed: $e");
    } finally {
      _setLoading(false);
    }
  }

  Future<void> storeRecommendation(Map<String, dynamic> result) async {
    try {
      await _coordinator.storeRecommendation(roomId: _roomId, result: result);
      await AnalyticsService().logEvent('ai_generation_success', params: {'room_id': _roomId});
    } catch (e) {
      debugPrint("Store recommendation failed: $e");
    }
  }

  // ====================================================================
  // 4. RESULT ACTIONS
  // ====================================================================
  Future<void> wantResult() async {
    if (_roomId.isEmpty) return;
    try {
      await _coordinator.wantResult(roomId: _roomId, doneUsers: [_uid]);
      await AnalyticsService().logEvent('result_accepted', params: {'room_id': _roomId});
    } catch (e) {
      debugPrint("Want Result failed: $e");
    }
  }

  // ====================================================================
  // 5. CLEANUP
  // ====================================================================
  Future<void> leaveRoom() async {
    if (_uid.isNotEmpty && _roomId.isNotEmpty) {
      try {
        await _coordinator.leaveRoom(roomId: _roomId, uid: _uid);
        await AnalyticsService().logEvent('room_left', params: {'room_id': _roomId});
      } catch (e) {
        debugPrint("Error leaving room: $e");
      }
    }
    _roomSubscription?.cancel();
    _roomSubscription = null;
    _localPreferences.clear();
    _isLocked = false;
    _recommendation = null;
    _isHost = false;
    _roomId = "";
    _participants.clear();
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}