import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// IMPORTS
import 'common_widgets.dart'; 
import '../viewmodels/home_vm.dart';
import '../viewmodels/room_vm.dart';

/// The central dashboard of the application.
///
/// **Features:**
/// 1. **Room Management:** Lists rooms fetched from Firestore via [HomeViewModel].
/// 2. **Room Creation:** Calls [HomeViewModel.newRoom] which uses the Coordinator to generate IDs.
/// 3. **Room Joining:** Validates codes before navigation.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _roomCodeController = TextEditingController();

  /// Initialization:
  /// Fetches the real list of hosted rooms from Firestore when the page loads.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeViewModel>().fetchRooms();
    });
  }

  @override
  void dispose() {
    _roomCodeController.dispose();
    super.dispose();
  }

  void _copyToClipboard(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied $code'), backgroundColor: Colors.green),
    );
  }

  // --- NAVIGATION & ACTIONS ---

  /// Handles Bottom Navigation Taps.
  /// 
  /// **Index 0 (New Room):**
  /// - Calls [HomeViewModel.newRoom].
  /// - If `error` is null -> Success SnackBar.
  /// - If `error` contains "limit" -> Show Alert Dialog.
  /// - Other errors -> Show Error SnackBar.
  void _onBottomNavTap(int index) async {
    if (index == 0) { // Create New Room
      final homeVM = context.read<HomeViewModel>();
      
      // Execute Logic
      String? error = await homeVM.newRoom();

      if (!mounted) return;

      if (error == null) {
        // Success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("New Room Created!"), backgroundColor: kPrimaryColor),
        );
      } else if (error.contains("limit")) {
        // Specific UI for Limit Reached
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Limit Reached"),
            content: Text(error),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))
            ],
          ),
        );
      } else {
        // Generic Error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
      }
    } else if (index == 2) { // Profile
      Navigator.pushNamed(context, '/settings');
    }
  }

  /// Handles Joining a Room.
  Future<void> _handleJoin(String code) async {
    final homeVM = context.read<HomeViewModel>();
    final roomVM = context.read<RoomViewModel>();

    // 1. Validate existence
    bool canJoin = await homeVM.joinRoom(code);
    
    if (!mounted) return;

    if (canJoin) {
       // 2. Initialize Session
       await roomVM.joinRoom(code);
       // 3. Navigate
       Navigator.pushNamed(context, '/room');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Room not found or network error."),
          backgroundColor: Colors.red,
        ),
      );
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
            // --- JOIN SECTION ---
            const Text("Join room", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            AuthBox(
              child: Column(
                children: [
                  AuthTextField(
                    labelText: "Enter Room Code",
                    obscureText: false,
                    controller: _roomCodeController,
                    prefixIcon: const Icon(Icons.vpn_key),
                  ),
                  const SizedBox(height: 15),
                  AuthButton(
                    text: homeVM.isLoading ? "Checking..." : "Join",
                    onPressed: homeVM.isLoading ? null : () => _handleJoin(_roomCodeController.text),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
            
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
            
            // 1. Spinner (Loading + Empty)
            if (homeVM.isLoading && homeVM.hostedRooms.isEmpty)
              const Center(child: CircularProgressIndicator(color: kPrimaryColor)),
            
            // 2. Empty State (Not Loading + Empty)
            if (!homeVM.isLoading && homeVM.hostedRooms.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: Text("No rooms yet. Tap the Burger button to create one!", style: TextStyle(color: Colors.grey))),
              ),
            
            // 3. Room List (Spread Operator)
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
                  // Buttons
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.copy, color: kPrimaryColor),
                        onPressed: () => _copyToClipboard(roomId),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                        onPressed: () => _handleJoin(roomId),
                      )
                    ],
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