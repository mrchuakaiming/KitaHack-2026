import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// [IMPORT] Local Widgets & ViewModel
import 'common_widgets.dart'; 
import '../viewmodels/room_vm.dart';

/// **RoomPage (Lobby View)**
class RoomPage extends StatefulWidget {
  const RoomPage({super.key});

  @override
  State<RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends State<RoomPage> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  
  static const CameraPosition _kDefaultLocation = CameraPosition(
    target: LatLng(37.7749, -122.4194),
    zoom: 14.0,
  );

  final List<String> _cuisineOptions = [
    'American', 
    'Arab', 
    'Chinese', 
    'Fast Food', 
    'French', 
    'Indian', 
    'Indonesian',
    'Italian', 
    'Japanese', 
    'Korean', 
    'Malay', 
    'Mamak',
    'Mediterranean', 
    'Mexican', 
    'Nyonya',
    'Seafood',
    'Thai', 
    'Vegetarian',
    'Vietnamese', 
    'Western',
  ];

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

  // removed _showAddDialog since custom input is no longer allowed

  void _handleBottomNavTap(int index) {
     if (index == 1) {
       Navigator.pushReplacementNamed(context, '/home');
     }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RoomViewModel>();
    
    // --- DETERMINE CURRENT SCREEN STATE ---
    bool showResult = vm.recommendation != null;
    bool isParticipantWaiting = !vm.isHost && vm.isLocked; 
    bool showInputScreen = !showResult && !isParticipantWaiting;

    // Helper boolean: Are inputs enabled?
    // Disabled if: Submission is Full (Spectator), User is Locked (Done), or User is Host (View Only)
    bool inputsDisabled = vm.isSubmissionFull || vm.isLocked || vm.isHost;

    return Scaffold(
      backgroundColor: kBackgroundColor,
      
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
              border: Border.all(color: kPrimaryColor.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                Text(
                  "ID: ${vm.roomId}", 
                  style: const TextStyle(fontWeight: FontWeight.bold, color: kPrimaryColor)
                ),
                const SizedBox(width: 5),
                const Icon(Icons.copy, size: 14, color: kPrimaryColor),
              ],
            ),
          )
        ],
      ),
      
      body: SingleChildScrollView(
        child: Column(
          children: [
            
            // ====================================================
            // STATE 1: RESULT SCREEN
            // ====================================================
            if (showResult) ...[
               Container(
                 margin: const EdgeInsets.all(20),
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
               Padding(
                 padding: const EdgeInsets.symmetric(horizontal: 20),
                 child: AuthButton(
                   text: "Leave Room",
                   onPressed: () async {
                     await vm.leaveRoom();
                     if (context.mounted) Navigator.pushReplacementNamed(context, '/home');
                   },
                 ),
               )
            ]

            // ====================================================
            // STATE 2: WAITING SCREEN
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
            // STATE 3: INPUT / VOTING SCREEN
            // ====================================================
            else if (showInputScreen) ...[
               
               // --- MAP SECTION ---
               SizedBox(
                 height: 250,
                 width: double.infinity,
                 child: Stack(
                   children: [
                     GoogleMap(
                       mapType: MapType.normal,
                       initialCameraPosition: _kDefaultLocation,
                       myLocationEnabled: true,
                       zoomControlsEnabled: false, 
                       markers: _markers,
                       onMapCreated: (GoogleMapController controller) {
                         _mapController = controller;
                       },
                     ),
                     // Hint Overlay
                     Positioned(
                       bottom: 10, right: 10,
                       child: Container(
                         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                         decoration: BoxDecoration(
                           color: Colors.white.withOpacity(0.9), 
                           borderRadius: BorderRadius.circular(20),
                           boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)]
                         ),
                         child: const Text(
                           "Tap a restaurant to add it!", 
                           style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)
                         ),
                       ),
                     ),
                   ],
                 ),
               ),

               Padding(
                 padding: const EdgeInsets.all(20),
                 child: Column(
                   children: [
                     // --- WARNINGS ---
                     if (vm.isSubmissionFull)
                       Container(
                         width: double.infinity,
                         margin: const EdgeInsets.only(bottom: 20),
                         padding: const EdgeInsets.all(12),
                         decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange.shade200)),
                         child: Row(
                           children: const [
                             Icon(Icons.info_outline, color: Colors.orange),
                             SizedBox(width: 10),
                             Expanded(child: Text("Voting is full (12 votes max). You are spectating.", style: TextStyle(color: Colors.orange, fontSize: 13))),
                           ],
                         ),
                       ),

                     // --- BUDGET SLIDER ---
                     AuthBox(
                       child: Column(
                         children: [
                           const Text("Budget Range", style: TextStyle(fontWeight: FontWeight.bold)),
                           RangeSlider(
                             values: vm.budgetRange,
                             min: 0, max: 100, divisions: 20,
                             activeColor: kPrimaryColor,
                             labels: RangeLabels("\$${vm.budgetRange.start.round()}", "\$${vm.budgetRange.end.round()}"),
                             // Disable if Spectating, Locked, or Host
                             onChanged: inputsDisabled ? null : (v) => vm.setBudget(v),
                           ),
                         ],
                       ),
                     ),
                     const SizedBox(height: 20),

                     // --- CUISINE CHIPS ---
                     AuthBox(
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           Row(
                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                             children: const [
                               Text("Quick Select Cuisines", style: TextStyle(fontWeight: FontWeight.bold)),
                               // Custom Add Button Removed as per requirement
                             ],
                           ),
                           const SizedBox(height: 10),
                           
                           Wrap(
                             spacing: 8.0, 
                             runSpacing: 4.0, 
                             children: _cuisineOptions.map((cuisine) {
                               final isSelected = vm.preferences.contains(cuisine);
                               return FilterChip(
                                 label: Text(cuisine),
                                 selected: isSelected,
                                 selectedColor: kPrimaryColor.withOpacity(0.2),
                                 checkmarkColor: kPrimaryColor,
                                 labelStyle: TextStyle(
                                   color: isSelected ? kPrimaryColor : Colors.black87,
                                   fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                 ),
                                 // Disable if Spectating, Locked, or Host
                                 onSelected: inputsDisabled ? null : (bool selected) {
                                   if (selected) {
                                     vm.addPreference(cuisine);
                                   } else {
                                     vm.removePreference(cuisine);
                                   }
                                 },
                               );
                             }).toList(),
                           ),
                         ],
                       ),
                     ),
                     const SizedBox(height: 20),

                     // --- SELECTED LIST VIEW ---
                     if (vm.preferences.isNotEmpty)
                       AuthBox(
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             const Text("Your Selection", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                             const SizedBox(height: 5),
                             ...vm.preferences.map((pref) {
                               final isKnownCuisine = _cuisineOptions.contains(pref);
                               return ListTile(
                                 dense: true,
                                 contentPadding: EdgeInsets.zero,
                                 leading: Icon(
                                   isKnownCuisine ? Icons.restaurant_menu : Icons.place, 
                                   color: isKnownCuisine ? kPrimaryColor : Colors.blue
                                 ),
                                 title: Text(pref),
                                 // Disable delete if Spectating, Locked, or Host
                                 trailing: inputsDisabled ? null : IconButton(
                                   icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                                   onPressed: () => vm.removePreference(pref)
                                 ),
                               );
                             }),
                           ],
                         ),
                       ),

                     const SizedBox(height: 30),

                     // --- ACTION BUTTONS ---
                     if (vm.isHost)
                       // HOST VIEW
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
                           Text("${vm.participants.length} joined", style: const TextStyle(color: Colors.grey)),
                         ],
                       )
                     else
                       // GUEST VIEW
                       SizedBox(
                         width: double.infinity, height: 60,
                         child: ElevatedButton(
                           style: ElevatedButton.styleFrom(
                             // Disable if Voting is Full OR User already submitted
                             backgroundColor: (vm.isSubmissionFull || vm.isLocked) ? Colors.grey : kPrimaryColor,
                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                           ),
                           // Disable if Voting is Full OR User already submitted
                           onPressed: (vm.isSubmissionFull || vm.isLocked) ? null : () => vm.lockSelection(),
                           child: Text(
                             vm.isSubmissionFull ? "Voting Full (Spectator)" : "Submit Preferences",
                             style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                           ),
                         ),
                       ),
                   ],
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