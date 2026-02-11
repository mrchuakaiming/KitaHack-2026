import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// [IMPORT] Business Logic & Services
import '../coordinators/coordinator.dart';
import '../models/preferences.dart';
import '../services/firestore_service.dart';
import '../services/analytics_service.dart';

/// **ViewModel for the Active Room Session**
///
/// **Architectural Role:**
/// This class is the "Brain" of the Room/Lobby screen. It acts as the bridge
/// between the UI (View) and the Backend logic (Coordinator).
///
/// **Key Responsibilities:**
/// 1. **Real-Time Sync:** Listens to the Firestore Room document.
/// 2. **Permissions:** Enforces Host vs. Guest restrictions.
/// 3. **Capacity Management:** Enforces the "12 Responses" limit (1 Host + 11 Guests).
/// 4. **Host Logic:** Ensures Host cannot vote but can generate results.
class RoomViewModel extends ChangeNotifier {

  // --- CONSTANTS ---
  /// The hard limit on how many *submissions* are accepted.
  /// Composition: 1 Host (Auto-submitted) + 11 Guests.
  /// Note: There is NO limit on how many people can *join* (view) the room.
  static const int maxSubmissions = 12;

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

  // --- Local User Selections ---
  RangeValues _budgetRange = const RangeValues(20, 50);
  List<String> _localPreferences = [];

  // --- Flags ---
  bool _isLocked = false;
  bool _isLoading = false;

  // --- Remote Room State ---
  bool _isHost = false;
  List<PreferencesModel> _participants = []; // List of those who have "Submitted" (or Host)
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

  /// Helper: Returns true if there is at least one participant.
  bool get allParticipantsReady => _participants.isNotEmpty;

  /// Helper: Checks if the **Submission Quota** is full.
  /// Does not prevent new users from joining, but prevents new submissions.
  bool get isSubmissionFull => _participants.length >= maxSubmissions;

  /// Returns a warning message if the voting slots are full.
  String? get roomCapacityWarning {
    if (isSubmissionFull) {
      return "Voting capacity reached ($maxSubmissions responses). You can spectate.";
    }
    return null;
  }

  /// Determines if the current user is allowed to interact with voting controls.
  /// Rules:
  /// 1. Hosts cannot vote (they are auto-done).
  /// 2. Users cannot vote if locked.
  bool get canVote => !_isHost && !_isLocked;

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
    _roomSubscription = _firestore.roomStream(_roomId).listen((data) {
      if (data == null) return;

      if (data.containsKey('aiRecommendation')) {
        _recommendation = data['aiRecommendation'];
      }

      if (_uid.isNotEmpty) {
        _isHost = (data['host_uid'] == _uid);
      }

      // Sync Participants (The list of people who have been accepted/submitted)
      if (data.containsKey('participants')) {
        final rawParticipants = data['participants'];
        if (rawParticipants is Map) {
          _participants = rawParticipants.entries.map((e) {
            if (e.value is Map) {
              return PreferencesModel.fromJson(
                  Map<String, dynamic>.from(e.value));
            }
            return PreferencesModel(
                roomId: _roomId, livePreferences: [], preferredCuisine: [], budget: [0, 0], dietaryRestrictions: []);
          }).toList();
        }
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
  // 2. USER ACTIONS (Voting & Selection)
  // ====================================================================

  Future<List<Map<String, dynamic>>> searchRestaurant(String query) async {
    // Hosts are not allowed to search/input preferences
    if (_isHost) return [];
    if (query.trim().isEmpty) return [];
    return await _coordinator.searchRestaurant(query);
  }

  void addPreference(String item) {
    // Host Guard: Host inputs are disabled
    if (_isHost) return; 
    
    if (!_isLocked && !_localPreferences.contains(item)) {
      _localPreferences.add(item);
      notifyListeners();
    }
  }

  void removePreference(String item) {
    // Host Guard: Host inputs are disabled
    if (_isHost) return;

    if (!_isLocked) {
      _localPreferences.remove(item);
      notifyListeners();
    }
  }

  void setBudget(RangeValues range) {
    // Host Guard: Host inputs are disabled
    if (_isHost) return;

    if (!_isLocked) {
      _budgetRange = range;
      notifyListeners();
    }
  }

  /// Submits the user's votes to the backend.
  Future<void> submitPreference() async {
    if (_uid.isEmpty || _roomId.isEmpty) return;

    // 1. HOST GUARD
    // Hosts are "Auto-Submitted" upon creation/joining.
    // They are not allowed to submit manual preferences.
    if (_isHost) {
      debugPrint("Host attempted to submit preference. Action blocked.");
      return;
    }

    // 2. CAPACITY CHECK (Race Condition Protection)
    // If we have 12 responses (1 Host + 11 Guests), new submissions are rejected.
    // EXCEPTION: If the user is ALREADY in the participants list, they are updating
    // their existing vote, which is allowed.
    if (isSubmissionFull) {
      final isExistingParticipant = _participants.any((p) {
        // Safe check for UID presence in the model
        try { return (p as dynamic).uid == _uid; } catch (_) { return false; }
      });

      if (!isExistingParticipant) {
        debugPrint("Submission rejected: Quota full ($maxSubmissions).");
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
      
      await AnalyticsService().logEvent(
        'preferences_submitted',
        params: {'room_id': _roomId, 'is_host': _isHost}
      );

    } catch (e) {
      debugPrint("Submit failed: $e");
      _isLocked = false;
    } finally {
      _setLoading(false);
    }
  }

  void lockSelection() => submitPreference();

  // ====================================================================
  // 3. HOST ACTIONS (Generation)
  // ====================================================================

  /// Triggers the AI to generate a recommendation.
  /// **Access:** Host Only.
  Future<void> generateRecommendation() async {
    // Strict Host Check
    if (!_isHost || _roomId.isEmpty) return;

    _setLoading(true);

    try {
      await AnalyticsService()
          .logEvent('ai_generation_started', params: {'room_id': _roomId});

      final result =
          await _coordinator.generateRecommendation(roomId: _roomId);

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
      await AnalyticsService()
          .logEvent('ai_generation_success', params: {'room_id': _roomId});
    } catch (e) {
      debugPrint("Store recommendation failed: $e");
    }
  }

  // ====================================================================
  // 4. RESULT ACTIONS & CLEANUP
  // ====================================================================

  Future<void> wantResult() async {
    if (_roomId.isEmpty) return;
    try {
      await _coordinator.wantResult(roomId: _roomId);
      await AnalyticsService()
          .logEvent('result_accepted', params: {'room_id': _roomId});
    } catch (e) {
      debugPrint("Want Result failed: $e");
    }
  }

  Future<void> leaveRoom() async {
    if (_uid.isNotEmpty && _roomId.isNotEmpty) {
      try {
        await _coordinator.leaveRoom(roomId: _roomId, uid: _uid);
        await AnalyticsService()
            .logEvent('room_left', params: {'room_id': _roomId});
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