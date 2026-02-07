import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Clipboard
import 'package:provider/provider.dart';

import 'common_widgets.dart'; 
import '../viewmodels/home_vm.dart';

// 
// Visualizing a dashboard that now includes a list of "Your Active Rooms" below the Join card.

/// **The Central Dashboard (Home)**
///
/// **Role:**
/// The landing page for authenticated users.
///
/// **Features:**
/// 1.  **Join Room:** Prominent input field.
/// 2.  **Your Rooms:** A horizontal or vertical list of active rooms hosted by the user.
/// 3.  **Create Room:** Quick action via bottom nav.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // ====================================================================
  // UI STATE
  // ====================================================================
  
  final TextEditingController _joinInputController = TextEditingController();

  // ====================================================================
  // LIFECYCLE
  // ====================================================================

  @override
  void initState() {
    super.initState();
    // Fetch hosted rooms when the page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeViewModel>().fetchHostedRooms();
    });
  }

  @override
  void dispose() {
    _joinInputController.dispose();
    super.dispose();
  }

  // ====================================================================
  // ACTIONS
  // ====================================================================

  void _handleJoin() async {
    final vm = context.read<HomeViewModel>();
    final roomId = _joinInputController.text.trim().toUpperCase();

    if (roomId.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Room ID must be 6 characters.")),
      );
      return;
    }

    bool success = await vm.joinRoom(roomId);
    if (!mounted) return;

    if (success) {
      Navigator.pushNamed(context, '/room', arguments: roomId);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(vm.errorMessage ?? "Failed to join room."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Helper to join a room directly from the list tap
  void _joinExistingRoom(String roomId) async {
    final vm = context.read<HomeViewModel>();
    // We can reuse the join logic, or just navigate directly since we know we are the host.
    // Re-using join logic ensures consistency (checks if room still exists in DB).
    bool success = await vm.joinRoom(roomId);
    if (success && mounted) {
      Navigator.pushNamed(context, '/room', arguments: roomId);
    }
  }

  void _handleCreate() async {
    final vm = context.read<HomeViewModel>();
    String? newRoomId = await vm.createRoom();

    if (!mounted) return;

    if (newRoomId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Room Created!"), backgroundColor: Colors.green),
      );
      Navigator.pushNamed(context, '/room', arguments: newRoomId);
    } else {
      if (vm.errorMessage?.contains("limit") == true) {
        _showLimitDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(vm.errorMessage ?? "Failed to create room."), 
            backgroundColor: Colors.red
          ),
        );
      }
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Room Code Copied!"), duration: Duration(seconds: 1)),
    );
  }

  void _showLimitDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Hosting Limit Reached"),
        content: const Text(
          "You are already hosting 5 active rooms.\n\nPlease finish or leave an existing room before creating a new one.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))
        ],
      ),
    );
  }

  void _onBottomNavTap(int index) {
    switch (index) {
      case 0: _handleCreate(); break;
      case 1: break; // Home
      case 2: Navigator.pushNamed(context, '/settings'); break;
    }
  }

  // ====================================================================
  // UI BUILD
  // ====================================================================

  @override
  Widget build(BuildContext context) {
    final homeVM = context.watch<HomeViewModel>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      
      appBar: AppBar(
        title: const Text(
          "What2Eat", 
          style: TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold, fontSize: 24)
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),

      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Hungry?", 
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)
                ),
                const Text(
                  "Let's decide where to eat.", 
                  style: TextStyle(fontSize: 16, color: Colors.grey)
                ),
                const SizedBox(height: 30),

                // --- JOIN ROOM CARD ---
                AuthBox(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.login, color: kPrimaryColor),
                          SizedBox(width: 10),
                          Text("Join a Session", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 15),
                      const Text("Enter the 6-character code shared by your host:"),
                      const SizedBox(height: 15),
                      
                      TextField(
                        controller: _joinInputController,
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 6,
                        decoration: const InputDecoration(
                          hintText: "e.g. A1B2C3",
                          border: OutlineInputBorder(),
                          counterText: "", 
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        style: const TextStyle(letterSpacing: 4, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 20),
                      
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimaryColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: homeVM.isLoading ? null : _handleJoin,
                          child: const Text("Join Room", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // --- YOUR ACTIVE ROOMS ---
                if (homeVM.hostedRooms.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Your Active Rooms", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Text("${homeVM.hostedRooms.length}/5", style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  
                  // Horizontal List of Rooms
                  SizedBox(
                    height: 140, // Height for cards
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: homeVM.hostedRooms.length,
                      itemBuilder: (ctx, index) {
                        final roomId = homeVM.hostedRooms[index];
                        return Container(
                          width: 160,
                          margin: const EdgeInsets.only(right: 15, bottom: 5, top: 5),
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 4, offset: const Offset(0, 2))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Icon(Icons.meeting_room, color: Colors.orange),
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: const Icon(Icons.copy, size: 18, color: Colors.grey),
                                    onPressed: () => _copyToClipboard(roomId),
                                  ),
                                ],
                              ),
                              Text(roomId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    side: const BorderSide(color: kPrimaryColor),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () => _joinExistingRoom(roomId),
                                  child: const Text("Enter", style: TextStyle(color: kPrimaryColor)),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // --- CREATE PROMPT ---
                Center(
                  child: Column(
                    children: [
                      if (homeVM.hostedRooms.isEmpty) ...[
                        const SizedBox(height: 20),
                        Icon(Icons.add_circle_outline, size: 60, color: Colors.grey.shade400),
                        const SizedBox(height: 10),
                        const Text("Host a new session", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
                        const SizedBox(height: 5),
                        const Text("Tap the button below to start.", style: TextStyle(color: Colors.grey)),
                      ]
                    ],
                  ),
                ),
                
                // Extra padding for bottom nav
                const SizedBox(height: 50),
              ],
            ),
          ),

          if (homeVM.isLoading)
            Container(
              color: Colors.black.withValues(),
              child: const Center(child: CircularProgressIndicator(color: kPrimaryColor)),
            ),
        ],
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        onTap: _onBottomNavTap,
        selectedItemColor: kPrimaryColor,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.add_box), label: 'New Room'),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Profile'),
        ],
      ),
    );
  }
}