import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'common_widgets.dart'; 
import '../viewmodels/home_vm.dart';

/// The central dashboard of the application.
///
/// **Current Capabilities:**
/// 1.  **Create Room:** Via the Bottom Navigation (Burger Icon).
/// 2.  **View Created Rooms:** Lists rooms created in this session.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  
  // NOTE: 'initState' for fetching rooms is removed as HomeVM doesn't support it.
  // NOTE: 'Join Room' text controller is removed as HomeVM doesn't support joining.

  void _copyToClipboard(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied $code'), backgroundColor: Colors.green),
    );
  }

  // --- NAVIGATION & ACTIONS ---

  /// Handles Bottom Navigation Taps.
  void _onBottomNavTap(int index) async {
    if (index == 0) { // Burger Button (Create New Room)
      final homeVM = context.read<HomeViewModel>();
      
      // 1. Call ViewModel (Only newRoom is available)
      String? result = await homeVM.newRoom();

      if (!mounted) return;

      // 2. Handle Outcome
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("New Room Created!"), backgroundColor: kPrimaryColor),
        );
      } else if (result == "limit_reached") {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Limit Reached"),
            content: const Text("You can only host 5 rooms at a time."),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result), backgroundColor: Colors.red),
        );
      }
    } else if (index == 2) { // Profile
      Navigator.pushNamed(context, '/settings');
    }
  }

  @override
  Widget build(BuildContext context) {
    final homeVM = context.watch<HomeViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("What2Eat", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false, 
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Note: Join Room Section removed because VM doesn't support joinRoom()
            
            // --- HOSTED ROOMS HEADER ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Your Rooms", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Text("${homeVM.hostedRooms.length}/5 active", style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
            const SizedBox(height: 15),

            // --- LIST RENDERING ---
            
            // 1. Loading State
            if (homeVM.isLoading)
              const Center(child: CircularProgressIndicator(color: kPrimaryColor))
            
            // 2. Empty State
            else if (homeVM.hostedRooms.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    "No rooms created yet.\nTap the Burger button to create one.", 
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            
            // 3. Room List
            else
              ...homeVM.hostedRooms.map((roomId) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 5)],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // ID Display
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle),
                          child: const Icon(Icons.meeting_room, color: kPrimaryColor),
                        ),
                        const SizedBox(width: 15),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Room ID", style: TextStyle(color: Colors.grey, fontSize: 12)),
                            Text(roomId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1)),
                          ],
                        ),
                      ],
                    ),
                    // Copy Button
                    IconButton(
                      icon: const Icon(Icons.copy, color: kPrimaryColor),
                      onPressed: () => _copyToClipboard(roomId),
                    ),
                  ],
                ),
              )),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1, 
        onTap: _onBottomNavTap,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.lunch_dining), label: 'New Room'),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}