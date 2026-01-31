import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Clipboard
import 'package:provider/provider.dart';
import 'common_widgets.dart'; // Ensure this path is correct
import '../viewmodels/room_vm.dart';

class RoomPage extends StatefulWidget {
  const RoomPage({super.key});

  @override
  State<RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends State<RoomPage> {

  @override
  void initState() {
    super.initState();
    // Start polling/checking for results when page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RoomViewModel>().wantResult();
    });
  }
  
  // --- 1. The Main "Type Selection" Dialog ---
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

    // Step 3: Add to ViewModel
    if (finalResult != null) {
      vm.addPreference(finalResult);
    }
  }

  // --- 2. Google Maps Placeholder Dialog ---
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
                  // Select Button
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
            autofocus: true,
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
    // Access the shared RoomViewModel
    final vm = context.watch<RoomViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text("Lobby"), automaticallyImplyLeading: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 1. RESULT SECTION (If Decision Made)
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

            // 2. ROOM ID DISPLAY
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

            // 3. BUDGET
            AuthBox(
              child: Column(
                children: [
                  const Text("Budget Range", style: TextStyle(fontWeight: FontWeight.bold)),
                  RangeSlider(
                    values: vm.budgetRange,
                    min: 0, max: 100, divisions: 20,
                    activeColor: kPrimaryColor,
                    labels: RangeLabels("\$${vm.budgetRange.start.round()}", "\$${vm.budgetRange.end.round()}"),
                    onChanged: vm.isLocked ? null : (v) => vm.setBudget(v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 4. PREFERENCES LIST
            AuthBox(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Preferences", style: TextStyle(fontWeight: FontWeight.bold)),
                      // Only allow adding if NOT locked
                      if (!vm.isLocked)
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: kPrimaryColor, size: 30),
                          onPressed: () => _showAddDialog(context, vm),
                        ),
                    ],
                  ),
                  if (vm.preferences.isEmpty)
                    const Padding(padding: EdgeInsets.all(10), child: Text("No preferences yet", style: TextStyle(color: Colors.grey))),
                  
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

            // 5. ACTION BUTTON (Dynamic based on Role)
            if (vm.isHost && vm.recommendation == null)
              // HOST VIEW: Button to Generate Result
              AuthButton(
                text: vm.isLoading ? "Deciding..." : "Generate Recommendation",
                onPressed: () => vm.generateRecommendation(),
              )
            else if (vm.recommendation != null)
              // RESULT VIEW: Button to Leave/Reset
               AuthButton(
                text: "Leave Room",
                onPressed: () async {
                  await vm.leaveRoom();
                  if (context.mounted) Navigator.pushReplacementNamed(context, '/home');
                },
              )
            else
              // PARTICIPANT VIEW: "I'm Done" or "Waiting"
              AuthButton(
                text: vm.isLocked ? "Waiting for Host..." : "I'm Done",
                // Disable button if already locked
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