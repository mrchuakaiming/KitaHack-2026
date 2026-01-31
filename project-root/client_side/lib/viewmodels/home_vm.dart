import 'package:flutter/material.dart';
import 'dart:math';

class RoomSummary {
  final String id;
  RoomSummary(this.id);
}

class HomeViewModel extends ChangeNotifier {
  // --- STATE ---
  final List<RoomSummary> _hostedRooms = [
    RoomSummary("X92-B41"),
    RoomSummary("A7X-92B"),
  ];
  
  bool _isLoading = false;
  String? _joinError;

  // --- GETTERS ---
  List<RoomSummary> get hostedRooms => List.unmodifiable(_hostedRooms);
  bool get isLoading => _isLoading;
  String? get joinError => _joinError;

  // --- FUNCTIONS ---

  /// 1. Create a New Room
  Future<String?> newRoom() async {
    if (_hostedRooms.length >= 5) {
      return "You can only host 5 rooms at a time.";
    }

    _setLoading(true);

    // TODO: Call RoomService.createRoom()
    // TODO: Get the real ID from database
    await Future.delayed(const Duration(milliseconds: 500));
    
    // SIMULATION
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random();
    String newId = String.fromCharCodes(Iterable.generate(
      6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));

    _hostedRooms.insert(0, RoomSummary(newId));
    
    _setLoading(false);
    return null; // Success
  }

  /// 2. Join an Existing Room
  /// Returns true if join is successful, false if failed.
  Future<bool> joinRoom(String code) async {
    _joinError = null; // Reset error
    
    if (code.isEmpty) {
      _joinError = "Please enter a room code";
      notifyListeners();
      return false;
    }

    _setLoading(true);

    // TODO: Call RoomService.checkRoomExists(code)
    // TODO: Call RoomService.addParticipant(code, userId)
    // TODO: If room is locked/full, return false and set _joinError
    await Future.delayed(const Duration(seconds: 1));

    // SIMULATION: Check if ID exists in our local list or is "DEMO"
    bool exists = _hostedRooms.any((r) => r.id == code) || code == "DEMO-123";

    if (!exists) {
      _joinError = "Room ID not found.";
      _setLoading(false);
      return false;
    }

    _setLoading(false);
    return true; // Success: The View should now navigate to /room
  }

  /// 3. Fetch User's History
  Future<void> fetchRooms() async {
    _setLoading(true);
    // TODO: Call RoomService.getRoomsForUser()
    await Future.delayed(const Duration(seconds: 1));
    _setLoading(false);
  }

  // --- HELPER ---
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}