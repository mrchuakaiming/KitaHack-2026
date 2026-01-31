import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// IMPORTS
import 'common_widgets.dart'; 
import '../viewmodels/home_vm.dart';
import '../viewmodels/room_vm.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _roomCodeController = TextEditingController();

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

  void _onBottomNavTap(int index) async {
    if (index == 0) { // Burger Button (Create New Room)
      final homeVM = context.read<HomeViewModel>();
      
      // 1. Attempt to create new room
      String? error = await homeVM.newRoom();

      if (error == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("New Room Created!"), backgroundColor: kPrimaryColor),
          );
        }
      } else {
        // 2. Show Error if limit reached
        if (mounted) {
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
        }
      }
    } else if (index == 2) { // Profile
      Navigator.pushNamed(context, '/settings');
    }
  }

  Future<void> _handleJoin(String code) async {
    final homeVM = context.read<HomeViewModel>();
    final roomVM = context.read<RoomViewModel>();

    // 1. Validate existence via HomeVM
    bool canJoin = await homeVM.joinRoom(code);
    
    if (canJoin && mounted) {
       // 2. Initialize the Session in RoomVM
       await roomVM.joinRoom(code);
       
       // 3. Navigate to Lobby
       Navigator.pushNamed(context, '/room');
    }
  }

  @override
  Widget build(BuildContext context) {
    final homeVM = context.watch<HomeViewModel>();
    
    // We only read RoomVM here to check loading state if needed, 
    // but mainly HomeVM drives this page.

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
                    validator: (_) => homeVM.joinError, // Displays "Room ID not found"
                  ),
                  const SizedBox(height: 15),
                  AuthButton(
                    text: homeVM.isLoading ? "Joining..." : "Join",
                    onPressed: () => _handleJoin(_roomCodeController.text),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
            
            // --- HOSTED ROOMS LIST ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Your Rooms", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Text("${homeVM.hostedRooms.length}/5 active", style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
            const SizedBox(height: 15),

            if (homeVM.hostedRooms.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: Text("No rooms yet. Tap the Burger button to create one!", style: TextStyle(color: Colors.grey))),
              )
            else
              ...homeVM.hostedRooms.map((room) => Container(
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
                    // Room ID Display
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
                            Text(room.id, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1)),
                          ],
                        ),
                      ],
                    ),
                    
                    // Action Buttons
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.copy, color: kPrimaryColor),
                          onPressed: () => _copyToClipboard(room.id),
                        ),
                        // Enter Room Button
                        IconButton(
                          icon: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                          onPressed: () => _handleJoin(room.id),
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