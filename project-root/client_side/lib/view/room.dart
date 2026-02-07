import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'common_widgets.dart'; 
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
    final roomId = ModalRoute.of(context)?.settings.arguments as String?;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (roomId != null) {
        context.read<RoomViewModel>().setRoomId(roomId);
      }
      context.read<RoomViewModel>().wantResult();
    });
  }
  
  // --- DIALOGS (Simplified for brevity, assume existing implementation) ---
  void _showAddDialog(BuildContext context, RoomViewModel vm) { /* ... same as before ... */ }
  void _handleBottomNavTap(int index) { /* ... same as before ... */ }

  /// Helper to check if user has already submitted (Re-join logic)
  bool _hasUserSubmitted(RoomViewModel vm) {
    // Ideally check against remote participants list if UID is available
    return vm.isLocked; 
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RoomViewModel>();
    
    // --- DETERMINE VIEW STATE ---
    bool showResult = vm.recommendation != null;
    bool isParticipantWaiting = !vm.isHost && _hasUserSubmitted(vm);
    bool showInputScreen = !showResult && !isParticipantWaiting;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("Lobby"), 
        automaticallyImplyLeading: false,
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: kPrimaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kPrimaryColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Text(vm.roomId, style: const TextStyle(fontWeight: FontWeight.bold, color: kPrimaryColor)),
                const SizedBox(width: 5),
                const Icon(Icons.copy, size: 14, color: kPrimaryColor),
              ],
            ),
          )
        ],
      ),
      
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            
            // ====================================================
            // VIEW 1: RESULT SCREEN (Highest Priority)
            // ====================================================
            if (showResult) ...[
               Container(
                 width: double.infinity, padding: const EdgeInsets.all(20),
                 decoration: BoxDecoration(
                   color: Colors.white, borderRadius: BorderRadius.circular(20),
                   border: Border.all(color: Colors.green, width: 2),
                   boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.2), blurRadius: 10)],
                 ),
                 child: Column(
                   children: [
                     const Icon(Icons.emoji_events, size: 60, color: Colors.green),
                     const SizedBox(height: 10),
                     const Text("It's Decided!", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.green)),
                     const SizedBox(height: 10),
                     Text(
                       vm.recommendation?['name'] ?? "Unknown", 
                       style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold), 
                       textAlign: TextAlign.center
                     ),
                     Text(
                       vm.recommendation?['type'] ?? "Restaurant", 
                       style: TextStyle(fontSize: 16, color: Colors.green.shade700)
                     ),
                   ],
                 ),
               ),
               const SizedBox(height: 30),
               
               AuthButton(
                 text: "Leave Room",
                 onPressed: () async {
                   await vm.leaveRoom();
                   if (context.mounted) Navigator.pushReplacementNamed(context, '/home');
                 },
               )
            ]

            // ====================================================
            // VIEW 2: WAITING SCREEN
            // ====================================================
            else if (isParticipantWaiting) ...[
               const SizedBox(height: 60),
               Container(
                 padding: const EdgeInsets.all(30),
                 decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 10)]),
                 child: const Icon(Icons.hourglass_top_rounded, size: 60, color: kPrimaryColor),
               ),
               const SizedBox(height: 30),
               const Text("Preferences Submitted!", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kPrimaryColor)),
               const SizedBox(height: 15),
               const Text("Please wait for the host to\ngenerate a restaurant recommendation.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 16)),
               const SizedBox(height: 60),
               const CircularProgressIndicator(color: kPrimaryColor),
            ]

            // ====================================================
            // VIEW 3: INPUT / VOTING SCREEN
            // ====================================================
            else if (showInputScreen) ...[
               
               // Warning if Room is Full
               if (vm.isRoomFull)
                 Container(
                   width: double.infinity,
                   margin: const EdgeInsets.only(bottom: 20),
                   padding: const EdgeInsets.all(12),
                   decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.red.shade200)),
                   child: Row(
                     children: const [
                       Icon(Icons.warning_amber_rounded, color: Colors.red),
                       SizedBox(width: 10),
                       Expanded(child: Text("Maximum of 12 participants reached. No new preferences can be added.", style: TextStyle(color: Colors.red, fontSize: 13))),
                     ],
                   ),
                 ),

               AuthBox(
                 child: Column(
                   children: [
                     const Text("Budget Range", style: TextStyle(fontWeight: FontWeight.bold)),
                     RangeSlider(
                       values: vm.budgetRange,
                       min: 0, max: 100, divisions: 20,
                       activeColor: kPrimaryColor,
                       labels: RangeLabels("\$${vm.budgetRange.start.round()}", "\$${vm.budgetRange.end.round()}"),
                       onChanged: (vm.isRoomFull && !vm.isLocked) ? null : (v) => vm.setBudget(v), // Disable if full
                     ),
                   ],
                 ),
               ),
               const SizedBox(height: 20),

               AuthBox(
                 child: Column(
                   children: [
                     Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                         const Text("Preferences", style: TextStyle(fontWeight: FontWeight.bold)),
                         // Hide Add button if room is full
                         if (!vm.isRoomFull)
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
                         dense: true,
                         leading: Icon(isRestaurant ? Icons.store : Icons.restaurant_menu, color: isRestaurant ? Colors.blue : kPrimaryColor),
                         title: Text(pref),
                         trailing: IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => vm.removePreference(pref)),
                       );
                     }),
                   ],
                 ),
               ),
               const SizedBox(height: 30),

               // HOST CONTROLS or PARTICIPANT SUBMIT
               if (vm.isHost)
                 Column(
                   children: [
                     SizedBox(
                       width: double.infinity, height: 60,
                       child: ElevatedButton(
                         style: ElevatedButton.styleFrom(
                           backgroundColor: vm.allParticipantsReady ? Colors.green : Colors.grey,
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                         ),
                         onPressed: vm.allParticipantsReady 
                            ? () => vm.generateRecommendation() 
                            : null, 
                         child: Text(
                           vm.allParticipantsReady ? "Generate Recommendation" : "Waiting for Participants...",
                           style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                         ),
                       ),
                     ),
                     const SizedBox(height: 10),
                     Text("${vm.participants.length} joined (Max 12)", style: const TextStyle(color: Colors.grey)),
                   ],
                 )
               else
                 SizedBox(
                   width: double.infinity, height: 60,
                   child: ElevatedButton(
                     style: ElevatedButton.styleFrom(
                       backgroundColor: (vm.isRoomFull || vm.isLocked) ? Colors.grey : kPrimaryColor,
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                     ),
                     onPressed: (vm.isRoomFull || vm.isLocked) ? null : () => vm.lockSelection(),
                     child: Text(
                       vm.isRoomFull ? "Room Full" : "Submit Preferences",
                       style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                     ),
                   ),
                 ),
            ],
            
            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1, 
        onTap: _handleBottomNavTap, 
        selectedItemColor: kPrimaryColor, unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.lunch_dining), label: 'New Room'),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home and Leave Room'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}