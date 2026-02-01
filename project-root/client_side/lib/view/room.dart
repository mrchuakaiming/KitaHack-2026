import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'common_widgets.dart'; 
import '../viewmodels/room_vm.dart';

/// The active session screen (Lobby).
class RoomPage extends StatefulWidget {
  const RoomPage({super.key});

  @override
  State<RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends State<RoomPage> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RoomViewModel>().wantResult();
    });
  }
  
  // --- DIALOGS (Unchanged) ---
  void _showAddDialog(BuildContext context, RoomViewModel vm) async {
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
                      icon: Icons.store_rounded, label: "Restaurant",
                      color: Colors.blue.shade50, iconColor: Colors.blue,
                      onTap: () => Navigator.pop(context, 'Restaurant'),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildBigSelectionButton(
                      icon: Icons.restaurant_menu_rounded, label: "Cuisine",
                      color: Colors.orange.shade50, iconColor: kPrimaryColor,
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

    String? finalResult;
    if (selectionType == 'Restaurant') {
      finalResult = await _showGoogleMapsDialog();
    } else if (selectionType == 'Cuisine') {
      finalResult = await _showCuisineInputDialog();
    }

    if (finalResult != null) {
      vm.addPreference(finalResult);
    }
  }

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
              width: double.maxFinite, height: 400,
              child: Stack(
                children: [
                  Container(
                    color: Colors.grey.shade200, alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.map_rounded, size: 60, color: Colors.grey.shade400),
                        const SizedBox(height: 10),
                        const Text("Google Maps API", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 20, left: 20, right: 20,
                    child: AuthButton(
                      text: "Select Burger King (Demo)",
                      onPressed: () => Navigator.pop(context, "Restaurant: Burger King (Demo)"),
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

  Future<String?> _showCuisineInputDialog() {
    final TextEditingController controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Choose Cuisine", style: TextStyle(fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller, autofocus: true,
            decoration: InputDecoration(
              hintText: "e.g. Italian, Sushi, Tacos", filled: true, fillColor: kBackgroundColor, 
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
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
                if (controller.text.isNotEmpty) Navigator.pop(context, "Cuisine: ${controller.text}");
              },
              child: const Text("Add", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBigSelectionButton({
    required IconData icon, required String label, required VoidCallback onTap,
    required Color color, required Color iconColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: color, borderRadius: BorderRadius.circular(16),
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
  
  void _handleBottomNavTap(int index) {
    if (index == 1) {
      Navigator.pushReplacementNamed(context, '/home');
    } else if (index == 2) Navigator.pushReplacementNamed(context, '/settings');
    else Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RoomViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text("Lobby"), automaticallyImplyLeading: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // --- 1. RESULT SECTION ---
            if (vm.recommendation != null) ...[
               Builder(
                 builder: (context) {
                   final result = vm.recommendation!;
                   final name = result['name'] ?? "Unknown Place";
                   final type = result['type'] ?? "Result";

                   return Container(
                    width: double.infinity, padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50, borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.emoji_events, size: 50, color: Colors.green),
                        const SizedBox(height: 10),
                        const Text("It's Decided!", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
                        const SizedBox(height: 5),
                        Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                        Text(type, style: TextStyle(fontSize: 14, color: Colors.green.shade700)),
                      ],
                    ),
                   );
                 }
               ),
               const SizedBox(height: 20),
            ],

            // --- 2. ROOM ID DISPLAY ---
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
                        color: kPrimaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(30),
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

            // --- 3. BUDGET & PREFERENCES ---
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
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Preferences", style: TextStyle(fontWeight: FontWeight.bold)),
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
                      leading: Icon(isRestaurant ? Icons.store : Icons.restaurant_menu, color: isRestaurant ? Colors.blue : kPrimaryColor),
                      title: Text(pref),
                      trailing: vm.isLocked ? null : IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => vm.removePreference(pref)),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // --- 5. DYNAMIC ACTION BUTTON ---
            
            // LOGIC BRANCH 1: Result is already generated (Any User)
            if (vm.recommendation != null) 
               AuthButton(
                text: "Leave Room",
                onPressed: () async {
                  await vm.leaveRoom();
                  if (context.mounted) Navigator.pushReplacementNamed(context, '/home');
                },
              )

            // LOGIC BRANCH 2: HOST VIEW
            else if (vm.isHost)
               SizedBox(
                 width: double.infinity,
                 height: 60,
                 child: ElevatedButton(
                   style: ElevatedButton.styleFrom(
                     // COLOR LOGIC: Green if ready, Grey if waiting
                     backgroundColor: vm.allParticipantsReady ? Colors.green : Colors.grey,
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                   ),
                   // CLICK LOGIC: Clickable if ready, Null if waiting
                   onPressed: vm.allParticipantsReady 
                      ? () => vm.generateRecommendation() 
                      : null, 
                   child: Text(
                     vm.allParticipantsReady ? "Generate Recommendation" : "Waiting for Participants...",
                     style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                   ),
                 ),
               )

            // LOGIC BRANCH 3: PARTICIPANT VIEW
            else
              SizedBox(
                 width: double.infinity,
                 height: 60,
                 child: ElevatedButton(
                   style: ElevatedButton.styleFrom(
                     // COLOR LOGIC: Orange if editing, Grey if locked
                     backgroundColor: vm.isLocked ? Colors.grey : kPrimaryColor,
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                   ),
                   // CLICK LOGIC: Clickable if editing, Null if locked
                   onPressed: vm.isLocked 
                      ? null 
                      : () => vm.lockSelection(),
                   child: Text(
                     vm.isLocked ? "Waiting for Host..." : "Save Preferences",
                     style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                   ),
                 ),
               ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1, 
        onTap: _handleBottomNavTap, 
        selectedItemColor: kPrimaryColor, unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.lunch_dining), label: 'New Room'),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}