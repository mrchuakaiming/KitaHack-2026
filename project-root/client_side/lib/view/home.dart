import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'common_widgets.dart'; 
import '../viewmodels/home_vm.dart';
import '../viewmodels/room_vm.dart';

/// The central dashboard of the application.
///
/// This widget serves as the primary landing page after a user authenticates.
/// It provides two main functionalities:
/// 1. **Join an existing room:** Users can input a code to join a session.
/// 2. **Manage hosted rooms:** Displays a list of active rooms created by the user.
///
/// It also acts as a navigation hub, linking to the Room Creation logic (via the
/// burger menu icon) and the User Profile settings.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /// Controller for the "Enter Room Code" text field.
  final TextEditingController _roomCodeController = TextEditingController();

  @override
  void dispose() {
    _roomCodeController.dispose();
    super.dispose();
  }

  /// Copies the given [code] to the system clipboard and shows a confirmation SnackBar.
  ///
  /// This is used when the user taps the copy icon on a room card.
  void _copyToClipboard(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied $code'), backgroundColor: Colors.green),
    );
  }

  // --- NAVIGATION & ACTIONS ---

  /// Handles interactions with the [BottomNavigationBar].
  ///
  /// * **Index 0 (New Room):** Triggers the creation logic in [HomeViewModel].
  ///   If successful, it shows a success message. If the limit is reached, it shows an alert.
  /// * **Index 2 (Profile):** Navigates to the Settings page.
  /// * **Index 1 (Home):** No action needed as we are already here.
  void _onBottomNavTap(int index) async {
    if (index == 0) { // Burger Button (Create New Room)
      final homeVM = context.read<HomeViewModel>();
      
      // 1. Attempt to create new room
      // The ViewModel handles the logic (generating ID, adding to list).
      // It returns an error string if the user has hit the 5-room limit.
      String? error = await homeVM.newRoom();

      if (error == null) {
        // Success: Notify the user visually
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("New Room Created!"), backgroundColor: kPrimaryColor),
          );
        }
      } else {
        // 2. Show Error if limit reached
        // We use a dialog here because it requires user acknowledgement.
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

  /// Handles the logic for joining a room via a specific [code].
  ///
  /// This sequence involves:
  /// 1. **Validation:** Checks if the room exists using [HomeViewModel].
  /// 2. **Initialization:** Prepares the session data in [RoomViewModel].
  /// 3. **Navigation:** Pushes the user to the [RoomPage] (Lobby).
  Future<void> _handleJoin(String code) async {
    final homeVM = context.read<HomeViewModel>();
    final roomVM = context.read<RoomViewModel>();

    // 1. Validate existence via HomeVM
    // This checks against the local list or server to ensure the ID is valid.
    bool canJoin = await homeVM.joinRoom(code);
    
    if (canJoin && mounted) {
       // 2. Initialize the Session in RoomVM
       // This sets up the room ID and prepares the state for the lobby.
       await roomVM.joinRoom(code);
       
       // 3. Navigate to Lobby
       Navigator.pushNamed(context, '/room');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch HomeViewModel to rebuild when the list of rooms changes or loading state updates.
    final homeVM = context.watch<HomeViewModel>();
    
    // We only read RoomVM here to check loading state if needed, 
    // but mainly HomeVM drives this page.

    return Scaffold(
      appBar: AppBar(
        title: const Text("What2Eat", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false, // Prevents back button since this is a root page
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- JOIN SECTION ---
            // The top area allows users to manually type a code to enter a room.
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
                    // Displays validation error (e.g., "Room ID not found") from the VM
                    validator: (_) => homeVM.joinError, 
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
            // Displays the list of rooms currently managed by this user.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Your Rooms", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                // Displays the active count (e.g., "2/5 active")
                Text("${homeVM.hostedRooms.length}/5 active", style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
            const SizedBox(height: 15),

            // Empty State Handling
            if (homeVM.hostedRooms.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: Text("No rooms yet. Tap the Burger button to create one!", style: TextStyle(color: Colors.grey))),
              )
            else
              // Rendering the list of Room Cards
              ...homeVM.hostedRooms.map((room) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  // Subtle shadow for card effect
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
                    
                    // Action Buttons (Copy ID & Enter Room)
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
      // Custom Navigation Bar for switching between Creating, Home, and Profile
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