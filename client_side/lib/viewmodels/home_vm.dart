import 'package:flutter/material.dart';
import 'dart:math';

class RoomSummary {
  final String id;
  RoomSummary(this.id);
}

class HomeViewModel extends ChangeNotifier {
  // Dummy Data
  final List<RoomSummary> _hostedRooms = [
    RoomSummary("X92-B41"),
    RoomSummary("A7X-92B"),
  ];
  
  String? _joinError;

  List<RoomSummary> get hostedRooms => List.unmodifiable(_hostedRooms);
  String? get joinError => _joinError;

  // --- 1. CREATE ROOM (With Limit Validation) ---
  // Returns null if success, or an error message string if failed.
  String? createNewRoom() {
    if (_hostedRooms.length >= 5) {
      return "You can only host 5 rooms at a time.";
    }

    // Generate Random ID
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random();
    String newId = String.fromCharCodes(Iterable.generate(
      6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));

    _hostedRooms.insert(0, RoomSummary(newId));
    notifyListeners();
    return null; // Success
  }

  // --- 2. JOIN VALIDATION (Must be Existing) ---
  bool validateCode(String code) {
    if (code.isEmpty) {
      _joinError = "Please enter a room code";
      notifyListeners();
      return false;
    }

    // SIMULATION: Check if ID exists.
    // In a real app, this would be an API call. 
    // Here, we check if it matches one of OUR rooms, or a specific "Demo" room.
    bool exists = _hostedRooms.any((r) => r.id == code) || code == "DEMO-123";

    if (!exists) {
      _joinError = "Room ID not found.";
      notifyListeners();
      return false;
    }

    _joinError = null;
    notifyListeners();
    return true;
  }
}