import 'package:flutter/material.dart';

/// A custom bottom navigation bar widget used across the main screens of the application.
///
/// This widget provides a consistent navigation interface, allowing users to switch
/// between the core functionalities: Creating a Room (represented by a burger icon),
/// returning to the Home dashboard, and accessing User Profile settings.
class CustomBottomNav extends StatelessWidget {
  /// The index of the currently active tab.
  ///
  /// * `0`: Create / New Room (Burger Icon)
  /// * `1`: Home Dashboard (Home Icon)
  /// * `2`: Profile / Settings (Person Icon)
  ///
  /// This must be passed by the parent widget to ensure the correct icon is highlighted.
  final int currentIndex;

  /// Creates a [CustomBottomNav].
  ///
  /// Requires [currentIndex] to highlight the active tab.
  const CustomBottomNav({super.key, required this.currentIndex});

  /// Handles tap events on the navigation items.
  ///
  /// Uses [Navigator.pushReplacementNamed] to switch screens. This replaces the
  /// current route with the new one, preventing the "back button" stack from
  /// growing indefinitely as the user toggles between tabs.
  ///
  /// * [context]: The build context used for navigation.
  /// * [index]: The index of the tapped navigation item.
  void _onItemTapped(BuildContext context, int index) {
    // Optimization: Do nothing if the user taps the tab they are already on.
    if (index == currentIndex) return;

    switch (index) {
      case 0: // "Create" Tab (Burger Icon)
        // Currently routes to '/home' where the "Create Room" logic resides.
        // In the future, this could route to a dedicated creation screen.
        Navigator.pushReplacementNamed(context, '/home');
        break;
      case 1: // "Home" Tab
        // Routes to the main dashboard.
        Navigator.pushReplacementNamed(context, '/home');
        break;
      case 2: // "Profile" Tab
        // Routes to the settings/profile page.
        Navigator.pushReplacementNamed(context, '/settings');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (index) => _onItemTapped(context, index),
      // Visual styling for the navigation bar
      backgroundColor: Colors.white,
      selectedItemColor: Colors.black, // Color for the active tab icon/label
      unselectedItemColor: Colors.grey, // Color for inactive tab icons/labels
      showSelectedLabels: true,
      showUnselectedLabels: true,
      // 'fixed' type ensures items don't shift position when selected
      type: BottomNavigationBarType.fixed,
      items: const [
        // Index 0: The "Burger" button, conceptually for creating new sessions.
        BottomNavigationBarItem(icon: Icon(Icons.lunch_dining), label: 'Create'),
        
        // Index 1: The standard Home navigation.
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        
        // Index 2: Access to user profile and settings.
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ],
    );
  }
}