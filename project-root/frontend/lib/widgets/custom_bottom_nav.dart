import 'package:flutter/material.dart';

class CustomBottomNav extends StatelessWidget {
  final int currentIndex;

  const CustomBottomNav({super.key, required this.currentIndex});

  void _onItemTapped(BuildContext context, int index) {
    if (index == currentIndex) return;

    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/create_room');
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/home');
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/settings');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (index) => _onItemTapped(context, index),
      backgroundColor: Colors.white,
      
      // Active Color (Black when selected)
      selectedItemColor: Colors.black, 
      
      // Inactive Color (Greyish when not selected - what you asked for)
      unselectedItemColor: Colors.grey, 
      
      showSelectedLabels: false,
      showUnselectedLabels: false,
      items: const [
        BottomNavigationBarItem(
          // CHANGED: used lunch_dining for the food burger icon
          icon: Icon(Icons.lunch_dining), 
          label: 'Create Room',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }
}