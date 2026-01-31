import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'common_widgets.dart';
import '../viewmodels/room_vm.dart';

/// The active session screen (Lobby).
///
/// This widget represents the "Room" where users (both Hosts and Participants)
/// collaborate to decide where to eat.
///
/// **Key Features:**
/// * **Real-time updates:** Polls for results and preference changes.
/// * **Preference Management:** Allows adding/removing cuisines or restaurants.
/// * **Budget Control:** Shared budget slider.
/// * **Role-based Actions:**
///     * **Hosts:** Can trigger the final decision generation.
///     * **Participants:** Can "Lock in" their choices to signal readiness.
/// * **Result Display:** Shows the winning option once decided.
class RoomPage extends StatefulWidget {
  const RoomPage({super.key});

  @override
  State<RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends State<RoomPage> {

  /// Initializes the room state.
  ///
  /// We use `addPostFrameCallback` to trigger `wantResult()` after the first frame.
  /// This ensures the context is fully built before interacting with the Provider,
  /// starting the polling/listening process for the final recommendation.
  @override
  void initState() {
    super.initState();
    // Start polling/checking for results when page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RoomViewModel>().wantResult();
    });
  }
  
  // --- 1. The Main "Type Selection" Dialog ---

  /// prompts the user to choose between adding a "Restaurant" or a "Cuisine".
  ///
  /// This acts as the entry point for adding preferences. Based on the user's
  /// selection, it routes to either the Map dialog or the Text Input dialog.
  void _showAddDialog(BuildContext context, RoomViewModel vm) async {
    // Step 1: Ask "Restaurant or Cuisine?"
    String? selectionType = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Add Preference", style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("What are you craving?", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 20),
              Row(
                children: [
                  // Option A: Restaurant (Triggers Map)
                  Expanded(
                    child: _buildBigSelectionButton(
                      icon: Icons.store_rounded,
                      label: "Restaurant",
                      color: Colors.blue.shade50,
                      iconColor: Colors.blue,
                      onTap: () => Navigator.pop(context, 'Restaurant'),
                    ),
                  ),
                  const SizedBox(width: 15),
                  // Option B: Cuisine (Triggers Text Input)
                  Expanded(
                    child: _buildBigSelectionButton(
                      icon: Icons.restaurant_menu_rounded,
                      label: "Cuisine",
                      color: Colors.orange.shade50,
                      iconColor: kPrimaryColor,
                      onTap: () => Navigator.pop(context, 'Cuisine'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (selectionType == null || !mounted) return;

    // Step 2: Open the specific dialog based on selection
    String? finalResult;
    if (selectionType == 'Restaurant') {
      finalResult = await _showGoogleMapsDialog();
    } else if (selectionType == 'Cuisine') {
      finalResult = await _showCuisineInputDialog();
    }

    // Step 3: Add the result to the ViewModel
    // This updates the shared state so other users (conceptually) can see it.
    if (finalResult != null) {
      vm.addPreference(finalResult);
    }
  }

  // --- 2. Google Maps Placeholder Dialog ---

  /// Simulates a Google Maps selection interface.
  ///
  /// **Note:** This is currently a mock implementation. In a real production app,
  /// this would integrate `Maps_flutter` or the Google Places API to allow
  /// the user to search and select a real geolocation.
  Future<String?> _showGoogleMapsDialog() {
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: EdgeInsets.zero,
          content: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: Stack(
                children: [
                  // Fake Map Background
                  Container(
                    color: Colors.grey.shade200,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.map_rounded, size: 60, color: Colors.grey.shade400),
                        const SizedBox(height: 10),
                        const Text("Google Maps API", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      ],
                    ),
                  ),
                  // Select Button (Hardcoded for Demo)
                  Positioned(
                    bottom: 20, left: 20, right: 20,
                    child: AuthButton(
                      text: "Select Burger King (Demo)",
                      onPressed: () {
                        Navigator.pop(context, "Restaurant: Burger King (Demo)");
                      },
                    ),
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- 3. Cuisine Text Input Dialog ---

  /// A simple dialog allowing the user to type a cuisine name.
  Future<String?> _showCuisineInputDialog() {
    final TextEditingController controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Choose Cuisine", style: TextStyle(fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller,
            autofocus: true, // Keyboards opens immediately
            decoration: InputDecoration(
              hintText: "e.g. Italian, Sushi, Tacos",
              filled: true,
              fillColor: kBackgroundColor, 
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  Navigator.pop(context, "Cuisine: ${controller.text}");
                }
              },
              child: const Text("Add", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // --- UI Helper for Big Buttons ---

  /// A helper widget to create the large square buttons used in the `_showAddDialog`.
  Widget _buildBigSelectionButton({
    required IconData icon, 
    required String label, 
    required VoidCallback onTap,
    required Color color,
    required Color iconColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: iconColor.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: iconColor),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: iconColor)),
          ],
        ),
      ),
    );
  }
  
  // Handle Leaving the Room
  void _handleBottomNavTap(int index) {
    if (index == 1) { // Home
      Navigator.pushReplacementNamed(context, '/home');
    } else if (index == 2) { // Profile
       Navigator.pushReplacementNamed(context, '/settings');
    } else {
      // If clicking "Create" while in a room, we just go home for now
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Access the shared RoomViewModel. 
    // Using context.watch ensures the UI rebuilds whenever the room state changes
    // (e.g., someone adds a preference, budget changes, or result is ready).
    final vm = context.watch<RoomViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text("Lobby"), automaticallyImplyLeading: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // --- 1. RESULT SECTION ---
            // This section only appears when 'vm.recommendation' is not null.
            // It signifies that the Host has made a decision.
            if (vm.recommendation != null) ...[
               Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.emoji_events, size: 50, color: Colors.green),
                    const SizedBox(height: 10),
                    const Text("It's Decided!", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
                    const SizedBox(height: 5),
                    Text(vm.recommendation!, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
               ),
               const SizedBox(height: 20),
            ],

            // --- 2. ROOM ID DISPLAY ---
            // Shows the current Room Code so users can share it with friends.
            AuthBox(
              child: Column(
                children: [
                  const Text("CURRENT SESSION", style: TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 2)),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () {
                       Clipboard.setData(ClipboardData(text: vm.roomId));
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ID Copied!")));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: kPrimaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: kPrimaryColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(vm.roomId, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: kPrimaryColor, letterSpacing: 2)),
                          const SizedBox(width: 10),
                          const Icon(Icons.copy, size: 24, color: kPrimaryColor),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // --- 3. BUDGET SECTION ---
            // A slider that allows the group to set a price range.
            AuthBox(
              child: Column(
                children: [
                  const Text("Budget Range", style: TextStyle(fontWeight: FontWeight.bold)),
                  RangeSlider(
                    values: vm.budgetRange,
                    min: 0, max: 100, divisions: 20,
                    activeColor: kPrimaryColor,
                    labels: RangeLabels("\$${vm.budgetRange.start.round()}", "\$${vm.budgetRange.end.round()}"),
                    // Disable slider if the user has "Locked" their choices
                    onChanged: vm.isLocked ? null : (v) => vm.setBudget(v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // --- 4. PREFERENCES LIST ---
            // Displays all added restaurants/cuisines.
            AuthBox(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Preferences", style: TextStyle(fontWeight: FontWeight.bold)),
                      // Only allow adding new items if NOT locked
                      if (!vm.isLocked)
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: kPrimaryColor, size: 30),
                          onPressed: () => _showAddDialog(context, vm),
                        ),
                    ],
                  ),
                  if (vm.preferences.isEmpty)
                    const Padding(padding: EdgeInsets.all(10), child: Text("No preferences yet", style: TextStyle(color: Colors.grey))),
                  
                  // Render list items dynamically
                  ...vm.preferences.map((pref) {
                    final isRestaurant = pref.contains("Restaurant");
                    return ListTile(
                      leading: Icon(
                        isRestaurant ? Icons.store : Icons.restaurant_menu,
                        color: isRestaurant ? Colors.blue : kPrimaryColor,
                      ),
                      title: Text(pref),
                      trailing: vm.isLocked 
                        ? null 
                        : IconButton(
                            icon: const Icon(Icons.close, color: Colors.grey),
                            onPressed: () => vm.removePreference(pref),
                          ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // --- 5. ACTION BUTTON (Dynamic Logic) ---
            // This button changes function and text based on:
            // 1. User Role (Host vs Participant)
            // 2. Session State (Decision Made vs Pending)
            // 3. Lock State (Locked vs Open)
            
            if (vm.isHost && vm.recommendation == null)
              // CASE A: HOST VIEW (Before Decision)
              // The Host has the power to "Generate Recommendation" to end the voting.
              AuthButton(
                text: vm.isLoading ? "Deciding..." : "Generate Recommendation",
                onPressed: () => vm.generateRecommendation(),
              )
            else if (vm.recommendation != null)
              // CASE B: RESULT VIEW (After Decision)
              // Once a result exists, the button allows users to leave.
               AuthButton(
                text: "Leave Room",
                onPressed: () async {
                  await vm.leaveRoom();
                  if (context.mounted) Navigator.pushReplacementNamed(context, '/home');
                },
              )
            else
              // CASE C: PARTICIPANT VIEW (Pending)
              // Participants "Lock" their choices to signal they are ready.
              AuthButton(
                text: vm.isLocked ? "Waiting for Host..." : "I'm Done",
                // Disable button interaction if already locked
                onPressed: vm.isLocked ? () {} : () => vm.lockSelection(),
              ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1, 
        onTap: _handleBottomNavTap, 
        selectedItemColor: kPrimaryColor,
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