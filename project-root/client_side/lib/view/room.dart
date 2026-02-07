import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// [IMPORT] Local Widgets & ViewModel
import 'common_widgets.dart'; 
import '../viewmodels/room_vm.dart';

/// **RoomPage (Lobby View)**
/// 
/// This is the main interactive screen where users vote on their preferences.
/// 
/// **Key Features:**
/// 1. **Google Map:** Users can explore the area and tap restaurants to add them.
/// 2. **Cuisine Chips:** Quick-select hardcoded cuisines.
/// 3. **Budget Slider:** Set the price range.
/// 4. **Host Controls:** Only the host sees the "Generate" button.
class RoomPage extends StatefulWidget {
  const RoomPage({super.key});

  @override
  State<RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends State<RoomPage> {
  // ====================================================================
  // 1. STATE VARIABLES
  // ====================================================================

  /// Controller to programmatically move the map camera if needed.
  GoogleMapController? _mapController;
  
  /// The set of markers displayed on the map. 
  /// We use a [Set] instead of a List because markers must be unique.
  final Set<Marker> _markers = {};

  /// **Default Location:** San Francisco. 
  /// TODO: In production, replace this with `Geolocator.getCurrentPosition()`.
  static const CameraPosition _kDefaultLocation = CameraPosition(
    target: LatLng(37.7749, -122.4194),
    zoom: 14.0,
  );

  /// **Hardcoded Cuisines:**
  /// A static list of popular options for the FilterChips.
  final List<String> _cuisineOptions = [
    'Italian', 'Chinese', 'Japanese', 'Mexican', 
    'Indian', 'Thai', 'Burgers', 'Pizza', 
    'Sushi', 'Vegan', 'Halal', 'Dessert'
  ];

  // ====================================================================
  // 2. LIFECYCLE METHODS
  // ====================================================================

  @override
  void initState() {
    super.initState();
    
    // Retrieve the Room ID passed via Navigator arguments
    // Example: Navigator.pushNamed(context, '/room', arguments: 'room_123');
    final roomId = ModalRoute.of(context)?.settings.arguments as String?;
    
    // Use addPostFrameCallback to safely access Provider context after the first build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (roomId != null) {
        context.read<RoomViewModel>().setRoomId(roomId);
      }
      // Check if there is already a result pending for this user
      context.read<RoomViewModel>().wantResult();
    });
  }

  // ====================================================================
  // 3. MAP LOGIC
  // ====================================================================

  // ====================================================================
  // 4. HELPER METHODS
  // ====================================================================

  /// Shows a dialog to allow manual entry of a preference (e.g., "Tacos").
  void _showAddDialog(BuildContext context, RoomViewModel vm) {
    TextEditingController controller = TextEditingController();
    showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        title: const Text("Add Custom Item"),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: "e.g., 'Spicy Food' or 'Tacos'"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: const Text("Cancel")
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
            onPressed: () {
              if(controller.text.trim().isNotEmpty) {
                vm.addPreference(controller.text.trim());
              }
              Navigator.pop(ctx);
            }, 
            child: const Text("Add", style: TextStyle(color: Colors.white))
          )
        ],
      )
    );
  }

  /// Navigation Handler for the BottomNavigationBar
  void _handleBottomNavTap(int index) {
     if (index == 1) {
       // Index 1 is "Back to Home". 
       // We use pushReplacement to reset the navigation stack.
       Navigator.pushReplacementNamed(context, '/home');
     }
  }

  // ====================================================================
  // 5. MAIN BUILD METHOD
  // ====================================================================

  @override
  Widget build(BuildContext context) {
    // Watch the ViewModel for changes (e.g., new participants, result ready)
    final vm = context.watch<RoomViewModel>();
    
    // --- DETERMINE CURRENT SCREEN STATE ---
    // State 1: Result is ready (Show Winner)
    bool showResult = vm.recommendation != null;
    
    // State 2: Waiting Room (User submitted, but Host hasn't generated yet)
    // We check !vm.isHost because the Host should never see the "Waiting" screen;
    // the Host always sees the "Generate" button screen.
    bool isParticipantWaiting = !vm.isHost && vm.isLocked; 
    
    // State 3: Input Screen (Voting is active)
    bool showInputScreen = !showResult && !isParticipantWaiting;

    return Scaffold(
      backgroundColor: kBackgroundColor,
      
      // --- APP BAR ---
      appBar: AppBar(
        title: const Text("Lobby"), 
        automaticallyImplyLeading: false, // Hide back button
        actions: [
          // Room ID Badge (Top Right)
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
            // VIEW STATE 1: RESULT SCREEN
            // Displayed when the AI has finished generating.
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
            // VIEW STATE 2: WAITING SCREEN
            // Displayed to Guests who have already submitted.
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
            // VIEW STATE 3: INPUT / VOTING SCREEN
            // The main interface for selecting preferences.
            // ====================================================
            else if (showInputScreen) ...[
               
               // --- SECTION A: GOOGLE MAP ---
               SizedBox(
                 height: 250,
                 width: double.infinity,
                 child: Stack(
                   children: [
                     GoogleMap(
                       mapType: MapType.normal,
                       initialCameraPosition: _kDefaultLocation,
                       myLocationEnabled: true, // Shows blue dot if permission granted
                       zoomControlsEnabled: false, // Clean UI
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
                           color: Colors.white.withValues(), 
                           borderRadius: BorderRadius.circular(20),
                           boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]
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
                     // --- SECTION B: WARNINGS ---
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
                             Expanded(child: Text("Maximum of 12 participants reached.", style: TextStyle(color: Colors.red, fontSize: 13))),
                           ],
                         ),
                       ),

                     // --- SECTION C: BUDGET SLIDER ---
                     AuthBox(
                       child: Column(
                         children: [
                           const Text("Budget Range", style: TextStyle(fontWeight: FontWeight.bold)),
                           RangeSlider(
                             values: vm.budgetRange,
                             min: 0, max: 100, divisions: 20,
                             activeColor: kPrimaryColor,
                             // Show rounded values in labels (e.g., $20 - $50)
                             labels: RangeLabels("\$${vm.budgetRange.start.round()}", "\$${vm.budgetRange.end.round()}"),
                             // Disable slider if user has already locked in
                             onChanged: (vm.isRoomFull || vm.isLocked) ? null : (v) => vm.setBudget(v),
                           ),
                         ],
                       ),
                     ),
                     const SizedBox(height: 20),

                     // --- SECTION D: CUISINE CHIPS (Quick Select) ---
                     AuthBox(
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           Row(
                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                             children: [
                               const Text("Quick Select Cuisines", style: TextStyle(fontWeight: FontWeight.bold)),
                               // Manual Add Button (Pencil Icon)
                               if (!vm.isLocked)
                                 IconButton(
                                   icon: const Icon(Icons.edit, size: 20, color: Colors.grey),
                                   onPressed: () => _showAddDialog(context, vm),
                                   tooltip: "Add Custom",
                                 ),
                             ],
                           ),
                           const SizedBox(height: 10),
                           
                           // Using Wrap to create a flowing layout of chips
                           Wrap(
                             spacing: 8.0, // Horizontal gap
                             runSpacing: 4.0, // Vertical gap
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
                                 // Toggle logic
                                 onSelected: vm.isLocked ? null : (bool selected) {
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

                     // --- SECTION E: SELECTED LIST VIEW ---
                     // Displays everything the user has selected (Map picks + Cuisines)
                     if (vm.preferences.isNotEmpty)
                       AuthBox(
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             const Text("Your Selection", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                             const SizedBox(height: 5),
                             ...vm.preferences.map((pref) {
                               // Determine Icon: Is it a generic cuisine or a specific place?
                               final isKnownCuisine = _cuisineOptions.contains(pref);
                               return ListTile(
                                 dense: true,
                                 contentPadding: EdgeInsets.zero,
                                 leading: Icon(
                                   isKnownCuisine ? Icons.restaurant_menu : Icons.place, 
                                   color: isKnownCuisine ? kPrimaryColor : Colors.blue
                                 ),
                                 title: Text(pref),
                                 trailing: vm.isLocked ? null : IconButton(
                                   icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                                   onPressed: () => vm.removePreference(pref)
                                 ),
                               );
                             }),
                           ],
                         ),
                       ),

                     const SizedBox(height: 30),

                     // --- SECTION F: ACTION BUTTONS ---
                     if (vm.isHost)
                       // HOST VIEW: "Generate Recommendation"
                       Column(
                         children: [
                           SizedBox(
                             width: double.infinity, height: 60,
                             child: ElevatedButton(
                               style: ElevatedButton.styleFrom(
                                 // Button is Green if ready, Grey if waiting
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
                       // GUEST VIEW: "Submit Preferences"
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
                 ),
               ),
            ],
            
            const SizedBox(height: 40),
          ],
        ),
      ),
      
      // --- BOTTOM NAVIGATION ---
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