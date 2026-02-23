import 'package:flutter/material.dart';

/// **Custom Bottom Navigation Bar**
///
/// **Indices Mapping:**
/// * `0` -> Create Room (Action)
/// * `1` -> Home (Current Page)
/// * `2` -> Settings (Navigation)
class CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  
  /// Callback to allow the parent (Home) to intercept taps (e.g., for "Create Room").
  final Function(int)? onTap; 

  const CustomBottomNav({
    super.key, 
    required this.currentIndex,
    this.onTap, 
  });

  void _onItemTapped(BuildContext context, int index) {
    // 1. Priority: Delegate to Parent
    // This fixes the issue where taps were ignored or misrouted.
    if (onTap != null) {
      onTap!(index);
      return;
    }

    // 2. Default Navigation (Fallback)
    if (index == currentIndex) return;

    switch (index) {
      case 0: // Create Room
        Navigator.pushReplacementNamed(context, '/home'); 
        break;
      case 1: // Home
        Navigator.pushReplacementNamed(context, '/home');
        break;
      case 2: // Settings
        Navigator.pushReplacementNamed(context, '/settings');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 1),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => _onItemTapped(context, index),
        
        backgroundColor: Colors.white,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        elevation: 0,
        
        iconSize: 32.0,
        selectedFontSize: 16.0,
        unselectedFontSize: 14.0,

        items: const [
          // Index 0: Create Room (Burger Icon)
          BottomNavigationBarItem(
            icon: Icon(Icons.lunch_dining),
            label: 'Create Room',
          ),
          // Index 1: Home (Home Icon)
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          // Index 2: Settings (Gear Icon)
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}