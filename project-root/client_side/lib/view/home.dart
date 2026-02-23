import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'common_widgets.dart'; 
import 'bottom_nav.dart'; 
import '../viewmodels/home_vm.dart';

/// ==============================================================================
/// HOME PAGE WIDGET
/// ==============================================================================
/// The main dashboard of the "what2eat" application.
/// 
/// Provides the user interface for:
/// 1. Joining an existing room using a 6-character code.
/// 2. Viewing a list of rooms currently hosted by the user.
/// 3. Navigating to the room creation flow via the bottom navigation bar.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Navigation indices matching the CustomBottomNav widget
  static const int kNavIndexCreate = 0;
  static const int kNavIndexHome = 1;
  static const int kNavIndexSettings = 2;

  /// Controller for reading and clearing the 6-character room code input.
  final TextEditingController _joinInputController = TextEditingController();

  /// --------------------------------------------------------------------------
  /// LIFECYCLE
  /// --------------------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    // Ensures data fetching only occurs after the initial UI frame renders.
    // This prevents BuildContext errors when calling Provider during init.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
  }

  /// Commands the ViewModel to fetch the latest list of rooms hosted by this user.
  void _refreshData() {
    if (mounted) {
      context.read<HomeViewModel>().fetchHostedRooms();
    }
  }

  @override
  void dispose() {
    // Clean up the controller to prevent memory leaks when navigating away.
    _joinInputController.dispose();
    super.dispose();
  }

  /// --------------------------------------------------------------------------
  /// ACTIONS & HANDLERS
  /// --------------------------------------------------------------------------

  /// **Handles the "Join Room" button press.**
  /// 
  /// 1. Prevents action if a network request is already loading.
  /// 2. Validates the input length (exactly 6 characters).
  /// 3. Asks the ViewModel to verify the room exists in Firestore.
  /// 4. Navigates to the RoomPage on success or displays an error.
  void _handleJoin() async {
    final vm = context.read<HomeViewModel>();
    
    // UI Guard: Prevent spam clicks while processing a join request
    if (vm.isLoading) return; 

    // Standardize input format
    final roomId = _joinInputController.text.trim().toUpperCase();

    if (roomId.length != 6) {
      _showSnackBar("Code must be 6 characters.", isError: true);
      return;
    }

    // Await database verification
    bool exists = await vm.verifyRoomExists(roomId);
    
    // Ensure widget is still alive before executing context-dependent logic
    if (!mounted) return;

    if (exists) {
      _joinInputController.clear();
      // Route user to the room lobby and refresh home data upon return
      await Navigator.pushNamed(context, '/room', arguments: roomId);
      if (mounted) _refreshData();
    } else {
      _showSnackBar(vm.errorMessage ?? "Room not found.", isError: true);
    }
  }

  /// **Handles the "Create Room" action triggered from the bottom navigation.**
  /// 
  /// This includes the crucial UI lock to prevent the 5-room limit bypass.
  void _handleCreate() async {
    final vm = context.read<HomeViewModel>();
    
    // [FIX] UI Guard (Race Condition Prevention)
    // Instantly drops the tap if the ViewModel is already busy creating a room.
    if (vm.isLoading) return; 
    
    // Attempt to generate a room in the backend
    String? newRoomId = await vm.createRoom();

    if (!mounted) return;

    if (newRoomId != null) {
      _showSnackBar("Room $newRoomId Created!", isError: false);
    } else {
      // Display specific capacity or network errors returned by the ViewModel
      if (vm.errorMessage != null) {
        _showSnackBar(vm.errorMessage!, isError: true);
      }
    }
  }

  /// Routes bottom navigation taps to the appropriate handler or page.
  void _onNavTapped(int index) {
    switch (index) {
      case kNavIndexCreate: 
        _handleCreate(); 
        break;
      case kNavIndexHome: 
        _refreshData();
        break;
      case kNavIndexSettings: 
        Navigator.pushReplacementNamed(context, '/settings');
        break;
    }
  }

  /// --------------------------------------------------------------------------
  /// UI HELPERS
  /// --------------------------------------------------------------------------

  /// Displays a floating SnackBar for success/error feedback.
  /// [message] The text to display.
  /// [isError] Determines the background color and duration.
  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: isError ? const Duration(seconds: 4) : const Duration(seconds: 2),
      ),
    );
  }

  /// Copies text to the device clipboard and provides visual confirmation.
  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    _showSnackBar("Copied to clipboard!");
  }

  /// --------------------------------------------------------------------------
  /// MAIN BUILD
  /// --------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    // Watch the ViewModel to rebuild the UI when state (like _isLoading or _hostedRooms) changes
    final homeVM = context.watch<HomeViewModel>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("What2Eat", style: TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold, fontSize: 24)),
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
                const Text("Hungry?", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                const Text("Let's decide where to eat.", style: TextStyle(fontSize: 16, color: Colors.grey)),
                const SizedBox(height: 30),

                // === JOIN SECTION ===
                AuthBox(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Join a Session", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 15),
                      TextField(
                        controller: _joinInputController,
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 6,
                        decoration: const InputDecoration(
                          hintText: "Enter Code (e.g. A1B2C3)",
                          border: OutlineInputBorder(),
                          counterText: "", filled: true, fillColor: Colors.white,
                        ),
                        style: const TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
                          // Disable button interaction visually if loading
                          onPressed: homeVM.isLoading ? null : _handleJoin,
                          child: homeVM.isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text("Join Room", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // === ACTIVE ROOMS SECTION ===
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Your Active Rooms", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    // Displays current capacity against the hardcoded maximum of 5
                    Text("${homeVM.hostedRooms.length}/5", style: const TextStyle(color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 10),

                // Empty State vs Populated List
                if (homeVM.hostedRooms.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(30.0),
                      child: Text("No active rooms.\nTap the 'Burger' icon below to create one!", 
                        textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                    ),
                  )
                else
                  // Vertical list of active hosted rooms
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(), // Scroll managed by outer SingleChildScrollView
                    itemCount: homeVM.hostedRooms.length,
                    separatorBuilder: (ctx, index) => const SizedBox(height: 12),
                    itemBuilder: (ctx, index) {
                      // Reverse list to show the most recently created rooms at the top
                      final roomId = homeVM.hostedRooms.reversed.toList()[index];
                      return _buildRoomCard(roomId);
                    },
                  ),
                
                const SizedBox(height: 50),
              ],
            ),
          ),

          // === GLOBAL LOADING OVERLAY ===
          // Dims the screen and shows a spinner during async Room Creation or Validation
          if (homeVM.isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(child: CircularProgressIndicator(color: kPrimaryColor)),
            ),
        ],
      ),
      
      // Bottom navigation controls the primary flows of the dashboard
      bottomNavigationBar: CustomBottomNav(
        currentIndex: kNavIndexHome, 
        onTap: _onNavTapped, 
      ),
    );
  }

  /// Builds an interactive card representing an active room.
  /// Includes tap-to-enter functionality and a quick copy-to-clipboard button.
  Widget _buildRoomCard(String roomId) {
    return GestureDetector(
      onTap: () async {
        await Navigator.pushNamed(context, '/room', arguments: roomId);
        if (mounted) _refreshData();
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.meeting_room, color: Colors.orange, size: 28),
                const SizedBox(width: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Room Code", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    Text(roomId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.black87, letterSpacing: 1.5)),
                  ],
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 20, color: kPrimaryColor),
              onPressed: () => _copyToClipboard(roomId),
            ),
          ],
        ),
      ),
    );
  }
}