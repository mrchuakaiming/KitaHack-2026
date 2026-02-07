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
/// 1.  **Real-Time Sync:** Listens to the Firestore Room document to keep the
///     UI updated (e.g., when a result is found or new people join).
/// 2.  **Data Transformation:** Converts UI-friendly state (RangeValues, Strings)
///     into the strict [PreferencesModel] required by the backend.
/// 3.  **User Actions:** Handles voting (submit), searching, and leaving.
/// 4.  **Host Logic:** Enables "Generate" buttons only for the host.
/// 5.  **Analytics:** Logs user engagement (voting, results, leaving).
class RoomViewModel extends ChangeNotifier {

  // --- CONSTANTS ---
  static const int maxParticipants = 12; // 1 Host + 11 Guests

  // ====================================================================
  // DEPENDENCIES
  // ====================================================================

  /// Handles complex business logic (Auth + DB + AI).
  final Coordinator _coordinator;
  
  /// Used strictly for *listening* to data streams.
  final FirestoreService _firestore; 

  // ====================================================================
  // STATE PROPERTIES
  // ====================================================================

  /// The unique ID of the current room session.
  String _roomId = "";

  /// The current authenticated user ID.
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // --- Local User Selections (Pre-submission) ---
  
  /// The budget range selected by the user. Defaults to $20-$50.
  RangeValues _budgetRange = const RangeValues(20, 50);

  /// The list of preferences selected by the user (e.g., "Sushi", "Vegan").
  /// stored locally as Strings for UI chips, converted to Maps on submit.
  List<String> _localPreferences = [];

  /// Locks the UI after submission to prevent double-voting.
  bool _isLocked = false;
  
  /// Loading state for async operations (network requests).
  bool _isLoading = false;

  // --- Remote Room State (Synced via Stream) ---

  /// `true` if the current user is the Host of this room.
  /// Hosts see extra controls (e.g., "Generate Recommendation").
  bool _isHost = false;

  /// The list of participants who have joined/submitted.
  /// Populated from the Firestore document stream.
  List<PreferencesModel> _participants = [];

  /// The final result from the AI. `null` until generation completes.
  Map<String, dynamic>? _recommendation;

  /// Subscription to the Firestore document. Kept to cancel on dispose.
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
  /// Used to enable the "Generate" button for the host.
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

  /// Sets the Room ID and starts listening for real-time updates.
  ///
  /// **Usage:** Call this in `didChangeDependencies` or `initState` of the View.
  void setRoomId(String id) {
    if (_roomId != id && id.isNotEmpty) {
      _roomId = id;
      _subscribeToRoom();
    }
  }

  /// Subscribes to the Firestore Room Document using `roomStream`.
  ///
  /// **Logic:**
  /// 1.  listens to `rooms/{roomId}` via `roomStream` (returns Map?).
  /// 2.  On update:
  ///     - Checks `aiRecommendation` field (Did we get a result?).
  ///     - Checks `host_uid` (Am I the host?).
  ///     - Parses `participants` (Who is here?).
  /// 3.  Calls `notifyListeners()` to update the UI.
  void _subscribeToRoom() {
    _roomSubscription?.cancel();
    
    // [FIX]: Using roomStream which returns Stream<Map<String, dynamic>?>
    _roomSubscription = _firestore.roomStream(_roomId).listen((data) {
      // 1. Handle Null/Deleted Room
      if (data == null) return;

      // 2. Sync Recommendation (If AI is done)
      if (data.containsKey('aiRecommendation')) {
        _recommendation = data['aiRecommendation'];
      }

      // 3. Sync Host Status
      if (_uid.isNotEmpty) {
        _isHost = (data['host_uid'] == _uid);
      }

      // 4. Sync Participants
      // Firestore stores participants as a Map<UID, Map<String, dynamic>>.
      if (data.containsKey('participants')) {
        final rawParticipants = data['participants'];
        
        // Ensure it is a Map before iterating
        if (rawParticipants is Map) {
          _participants = rawParticipants.entries.map((e) {
            // Robustness: ensure value is Map
            if (e.value is Map) {
               return PreferencesModel.fromJson(Map<String, dynamic>.from(e.value));
            }
            // Fallback for malformed data
            return PreferencesModel(
               roomId: _roomId, 
               livePreferences: [], 
               preferredCuisine: [], 
               budget: [0,0], 
               dietaryRestrictions: []
            );
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

  /// Searches for restaurants via the Google Maps API (via Coordinator).
  ///
  /// **Returns:** A list of place suggestions (Name, Address, etc.).
  Future<List<Map<String, dynamic>>> searchRestaurant(String query) async {
    // Debounce or empty check
    if (query.trim().isEmpty) return [];
    
    // Delegate to Coordinator
    return await _coordinator.searchRestaurant(query);
  }

  /// Adds a preference tag (e.g., "Sushi") to the local list.
  void addPreference(String item) {
    if (!_isLocked && !_localPreferences.contains(item)) {
      _localPreferences.add(item);
      notifyListeners();
    }
  }

  /// Removes a preference tag from the local list.
  void removePreference(String item) {
    if (!_isLocked) {
      _localPreferences.remove(item);
      notifyListeners();
    }
  }

  /// Updates the budget range.
  void setBudget(RangeValues range) {
    if (!_isLocked) {
      _budgetRange = range;
      notifyListeners();
    }
  }

  /// Submits the user's votes to the backend.
  ///
  /// **Flow:**
  /// 1.  Locks the UI (`_isLocked = true`) to prevent changes.
  /// 2.  TRANSFORMATION: Converts UI state (RangeValues, List<String>) 
  ///     into the strict [PreferencesModel] format.
  /// 3.  Calls [Coordinator.submitPreference].
  /// 4.  **Analytics:** Logs 'preferences_submitted'.
  Future<void> submitPreference() async {
    if (_uid.isEmpty || _roomId.isEmpty) return;

    // CAPACITY CHECK
    // If the room is full and this user is NOT already in the list, block them.
    if (isRoomFull) {
       // We check if the current user ID is present in the _participants list 
       // to allow re-submission (updating votes) but block new users.
       // NOTE: This check assumes PreferencesModel can be linked to UID via logic 
       // or we rely on the coordinator to enforce this. 
       // For UI safety, we just return here.
       // (Real validation should happen on backend rules too).
       return;
    }

    _setLoading(true);

    try {
      // 1. Construct Data Model
      // Note: We use empty lists for Cuisine/Dietary here because the Coordinator
      // merges the User's Profile defaults with these "Live" preferences.
      final prefModel = PreferencesModel(
        roomId: _roomId,
        // Map Strings to [{'value': 'Sushi'}, {'value': 'No Spicy'}]
        livePreferences: _localPreferences.map((p) => {'value': p}).toList(),
        // Map RangeValues to [Min, Max]
        budget: [_budgetRange.start.round(), _budgetRange.end.round()],
        preferredCuisine: [], 
        dietaryRestrictions: [],
      );

      // 2. Delegate to Coordinator (Writes to DB)
      await _coordinator.submitPreference(
        uid: _uid,
        roomId: _roomId,
        preferences: prefModel,
      );

      // 3. Lock UI & Analytics
      _isLocked = true;
      
      await AnalyticsService().logEvent(
        'preferences_submitted',
        params: {
          'room_id': _roomId,
          'item_count': _localPreferences.length,
          'budget_min': _budgetRange.start.round(),
          'budget_max': _budgetRange.end.round(),
        }
      );

    } catch (e) {
      debugPrint("Submit failed: $e");
      // Unlock if failed so user can try again
      _isLocked = false;
    } finally {
      _setLoading(false);
    }
  }

  /// **Bridge Method:** Alias for `submitPreference` to match View calls.
  void lockSelection() => submitPreference();

  // ====================================================================
  // 3. HOST ACTIONS (Generation)
  // ====================================================================

  /// Triggers the AI to generate a recommendation.
  /// **Access:** Host Only.
  ///
  /// **Flow:**
  /// 1.  **Generate:** Calls Coordinator to run AI logic on the gathered preferences.
  /// 2.  **Store:** Saves the result to Firestore (triggering the stream for everyone).
  /// 3.  **Analytics:** Logs the AI generation event.
  Future<void> generateRecommendation() async {
    if (!_isHost || _roomId.isEmpty) return;

    _setLoading(true);

    try {
      // Analytics: Track start
      await AnalyticsService().logEvent('ai_generation_started', params: {'room_id': _roomId});

      // Step A: Get Result from AI Service
      final result = await _coordinator.generateRecommendation(roomId: _roomId);

      // Step B: Persist Result to Room Document
      // This will trigger the stream listener above, automatically showing the result
      await storeRecommendation(result);

    } catch (e) {
      debugPrint("Generation failed: $e");
    } finally {
      _setLoading(false);
    }
  }

  /// Stores the AI result in Firestore.
  /// Usually called internally by [generateRecommendation].
  Future<void> storeRecommendation(Map<String, dynamic> result) async {
    try {
      await _coordinator.storeRecommendation(roomId: _roomId, result: result);
      
      // Analytics: Track success
      await AnalyticsService().logEvent('ai_generation_success', params: {'room_id': _roomId});
    } catch (e) {
      debugPrint("Store recommendation failed: $e");
    }
  }

  // ====================================================================
  // 4. RESULT ACTIONS
  // ====================================================================

  /// Signals that the user has viewed/accepted the result.
  /// Used to update the "Done Users" list in the backend.
  Future<void> wantResult() async {
    if (_roomId.isEmpty) return;

    try {
      // Coordinator handles the logic of adding the current user to the 'done' list
      await _coordinator.wantResult(roomId: _roomId, doneUsers: [_uid]);
      
      await AnalyticsService().logEvent('result_accepted', params: {'room_id': _roomId});
    } catch (e) {
      debugPrint("Want Result failed: $e");
    }
  }

  // ====================================================================
  // 5. CLEANUP
  // ====================================================================

  /// Leaves the room and cleans up local state.
  ///
  /// **Flow:**
  /// 1.  Calls [Coordinator.leaveRoom] (Updates DB presence).
  /// 2.  Cancels stream subscription.
  /// 3.  Resets local variables.
  /// 4.  **Analytics:** Logs 'room_left'.
  Future<void> leaveRoom() async {
    if (_uid.isNotEmpty && _roomId.isNotEmpty) {
      try {
        await _coordinator.leaveRoom(roomId: _roomId, uid: _uid);
        
        await AnalyticsService().logEvent('room_left', params: {'room_id': _roomId});
      } catch (e) {
        debugPrint("Error leaving room: $e");
      }
    }

    // Local Cleanup
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

  // ====================================================================
  // INTERNAL HELPERS
  // ====================================================================

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}