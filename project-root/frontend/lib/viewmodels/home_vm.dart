import 'package:flutter/material.dart';

class RoomSummary {
  final String name;
  final String code;
  RoomSummary(this.name, this.code);
}

class HomeViewModel extends ChangeNotifier {
  // State
  final List<RoomSummary> _hostedRooms = [
    RoomSummary("Lunch with Team", "X92-B41"),
    RoomSummary("Family Dinner", "A7X-92B"),
  ];
  String? _joinError;

  // Getters
  List<RoomSummary> get hostedRooms => List.unmodifiable(_hostedRooms);
  String? get joinError => _joinError;

  // Actions
  bool validateCode(String code) {
    if (code.isEmpty) {
      _joinError = "Please enter a room code";
      notifyListeners();
      return false;
    }
    _joinError = null;
    notifyListeners();
    return true;
  }
}