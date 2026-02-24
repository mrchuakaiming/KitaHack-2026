import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../viewmodels/room_vm.dart';
import 'common_widgets.dart'; 
import 'bottom_nav.dart'; 

/// ==============================================================================
/// ROOM PAGE (View)
/// ==============================================================================
/// This file acts as the primary UI layer for an active room.
/// It observes the `RoomViewModel` via Provider to reactively rebuild the UI
/// based on the state of the room (e.g., waiting for users, submitting, or showing the AI result).
class RoomPage extends StatefulWidget {
  const RoomPage({super.key});

  @override
  State<RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends State<RoomPage> {
  
  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback to safely access the context after the first build.
    // This allows us to grab the Room ID passed from the previous route and initialize the ViewModel.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final String? roomId = ModalRoute.of(context)?.settings.arguments as String?;
      if (roomId != null && roomId.isNotEmpty) {
        context.read<RoomViewModel>().init(roomId);
      }
    });
  }

  /// Displays a floating UI banner at the bottom of the screen for brief user feedback.
  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Handles taps on the custom bottom navigation bar.
  /// It intercepts the navigation request, validates it through the ViewModel,
  /// and displays a warning dialog if the user is about to lose unsubmitted data.
  Future<void> _onBottomNavTap(int index) async {
    final vm = context.read<RoomViewModel>();
    
    // 1. Check if the ViewModel permits navigation at this specific state.
    bool isAllowed = vm.validateNavigation(index);
    if (!isAllowed) {
      if (vm.errorMessage != null) _showSnackBar(vm.errorMessage!, isError: true);
      return;
    }

    // 2. Safeguard: Prevent users from accidentally abandoning unsaved preferences.
    // If they have picked items but haven't submitted, force them to confirm.
    if (!vm.hasSubmitted && vm.preferenceCount > 0) {
      final bool confirmLeave = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: const Text("Discard Selection?", style: TextStyle(fontWeight: FontWeight.bold)),
            content: const Text(
              "You have selected preferences but haven't submitted them yet.\n\n"
              "Leaving now will discard your choices permanently.",
              style: TextStyle(height: 1.5, color: Colors.black87),
            ),
            actions: [
              TextButton(
                child: const Text("Stay", style: TextStyle(fontWeight: FontWeight.bold)), 
                onPressed: () => Navigator.pop(ctx, false) // Cancel leave
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text("Leave & Discard"), 
                onPressed: () => Navigator.pop(ctx, true) // Confirm leave
              ),
            ]
        )
      ) ?? false;
      
      if (!confirmLeave) return; // User chose to stay
    }

    // Clear temporary UI state before officially leaving the room
    vm.clearLocalPreferences(); 

    if (!mounted) return;
    
    // Execute routing
    if (index == 1) Navigator.pushReplacementNamed(context, '/home');
    else if (index == 0) Navigator.pushReplacementNamed(context, '/home'); 
    else if (index == 2) Navigator.pushReplacementNamed(context, '/settings');
  }

  /// Copies the current Room ID to the device clipboard for easy sharing.
  void _copyToClipboard(String id) {
    Clipboard.setData(ClipboardData(text: id));
    _showSnackBar('Room ID copied!', isError: false);
  }

  /// Triggered when the user clicks the '+' button to add a new preference.
  /// Enforces the maximum preference limit and opens the respective dialogs.
  void _handleAddButtonPress(RoomViewModel vm) async {
    if (vm.isLocked) return;
    if (vm.preferenceCount >= RoomViewModel.MAX_PREFS) {
      _showSnackBar("You can only choose up to 3 preferences!", isError: true);
      return;
    }

    // Step 1: Ask the user if they want to add a Restaurant or a Cuisine
    String? type = await _showTypeSelectionDialog();
    if (type == null || !mounted) return;

    // Step 2: Open the appropriate selection UI
    if (type == 'Restaurant') {
      final restaurant = await showDialog<Map<String, dynamic>>(
        context: context, 
        builder: (_) => _GoogleMapSearchDialog(vm: vm)
      );
      if (restaurant != null && mounted) vm.addRestaurant(restaurant);
    } else {
      final cuisine = await _showCuisineSelectionDialog();
      if (cuisine != null && mounted) vm.addCuisine(cuisine);
    }
  }

  /// Displays a modal prompting the user to select the category of their preference.
  Future<String?> _showTypeSelectionDialog() {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Add Preference", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Row(
          children: [
            Expanded(child: _buildBigBtn(Icons.store, "Restaurant", Colors.blue, () => Navigator.pop(context, 'Restaurant'))),
            const SizedBox(width: 15),
            Expanded(child: _buildBigBtn(Icons.restaurant_menu, "Cuisine", Colors.orange, () => Navigator.pop(context, 'Cuisine'))),
          ],
        ),
      ),
    );
  }

  /// Displays a modal containing predefined Cuisine options.
  Future<String?> _showCuisineSelectionDialog() {
    final list = [
      'American', 'Arab', 'Chinese', 'French', 'Indian', 
      'Indonesian', 'Italian', 'Japanese', 'Korean', 'Malay', 'Mamak',
      'Mediterranean', 'Mexican', 'Nyonya', 'Thai',
      'Vietnamese', 'Western'
    ];
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Choose Cuisine", style: TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              // Map standard list to clickable chips
              children: list.map((c) => ActionChip(
                elevation: 0,
                backgroundColor: Colors.grey.shade100,
                side: BorderSide.none,
                label: Text(c, style: const TextStyle(fontWeight: FontWeight.w500)), 
                onPressed: () => Navigator.pop(context, c)
              )).toList(),
            ),
          ),
        ),
      ),
    );
  }

  /// Helper widget to generate large, tappable category buttons (Restaurant/Cuisine).
  Widget _buildBigBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1), 
          borderRadius: BorderRadius.circular(16), 
          border: Border.all(color: color.withOpacity(0.3))
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, 
          children: [
            Icon(icon, color: color), 
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold))
          ]
        ),
      ),
    );
  }

  /// Helper widget to render standard section titles across the app.
  Widget _buildSectionHeader(String title, {Widget? action}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
        if (action != null) action,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch allows the UI to automatically rebuild whenever notifyListeners() is called in RoomViewModel.
    final vm = context.watch<RoomViewModel>();

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: const Text("Room", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent, 
        elevation: 0, 
        automaticallyImplyLeading: false, // Prevents the default back button to enforce custom navigation logic
      ),
      
      body: vm.roomId.isEmpty 
          ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
          // StreamBuilder listens directly to the Firestore Room document for global status changes (e.g. processing, finished)
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('rooms').doc(vm.roomId).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));

                final data = snapshot.data!.data() as Map<String, dynamic>?;
                if (data == null) return const Center(child: Text("Room ended."));

                // Safely update the ViewModel if new data arrives (e.g. the AI payload is written to the DB)
                WidgetsBinding.instance.addPostFrameCallback((_) {
                   if (mounted) vm.updateFromStream(data); 
                });

                // SCENARIO A: AI Generation Complete. Display the result screen.
                if (data.containsKey('output')) {
                  final output = data['output'];
                  if (output is Map && output.isNotEmpty) {
                      return _buildResultViewFromMap(Map<String, dynamic>.from(output));
                  }
                }

                // SCENARIO B: Host clicked Generate. Show the global processing screen.
                String status = data['status'] ?? 'waiting';
                if (status == 'processing') {
                  return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    CircularProgressIndicator(color: kPrimaryColor),
                    SizedBox(height: 20),
                    Text("AI is deciding...", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kPrimaryColor))
                  ]));
                }
                
                // SCENARIO C: Default Room View (Adding preferences, waiting)
                return _buildBodyContent(vm);
              },
            ),
      
      bottomNavigationBar: CustomBottomNav(
        currentIndex: 1, 
        onTap: _onBottomNavTap,
      ),
    );
  }

  /// Renders the final victory screen showing Gemini's restaurant choice.
  Widget _buildResultViewFromMap(Map<String, dynamic> result) {
    final name = result['suggestion_name'] ?? result['suggestion'] ?? "Unknown";
    final justification = result['justification'] ?? "We found a match!";
    final price = result['price_range'] ?? ""; 

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.restaurant_rounded, size: 50, color: kPrimaryColor),
              const SizedBox(height: 10),
              Text(
                "The Verdict",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.grey.shade800, letterSpacing: 1.2),
              ),
              const SizedBox(height: 25),
              
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 8))
                  ],
                  border: Border.all(color: Colors.grey.shade100, width: 1),
                ),
                child: Column(
                  children: [
                    if (price.toString().isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: kPrimaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                        child: Text(
                          "BUDGET: $price",
                          style: const TextStyle(color: kPrimaryColor, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    Text(
                      name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black87, height: 1.1),
                    ),
                    const SizedBox(height: 25),
                    const Divider(height: 1, color: Colors.black12),
                    const SizedBox(height: 25),

                    Column(
                      children: [
                        const Text("WHY THIS CHOICE?", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.5)),
                        const SizedBox(height: 8),
                        Text(
                          justification,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 15, height: 1.4, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.home, size: 16, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Text("Click 'Home' below to leave", style: TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Orchestrates the core interactive UI for the room.
  Widget _buildBodyContent(RoomViewModel vm) {
    // Only Guests who have submitted get sent to the passive waiting screen.
    // The Host bypasses this entirely to keep their UI visible so they can click 'Generate'.
    if (!vm.isHost && vm.isLocked) return _buildWaitingScreen(vm);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildRoomIdentityCard(vm),
          const SizedBox(height: 20),
          
          _buildBudgetCard(vm),
          const SizedBox(height: 20),

          _buildSubmittedPreferencesHeader(vm),
          const SizedBox(height: 20),
          
          _buildLivePreferencesSection(context, vm),
          
          // WARNING BANNER: Reminds users their local state is not yet saved to the cloud.
          // Disappears once the user (Host or Guest) successfully submits.
          if (vm.preferenceCount > 0 && !vm.hasSubmitted)
             Container(
               margin: const EdgeInsets.only(top: 15, bottom: 10),
               padding: const EdgeInsets.all(12),
               decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.shade200)),
               child: Row(
                 children: [
                   Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 24),
                   const SizedBox(width: 12),
                   const Expanded(child: Text("Don't forget to submit! Leaving now will discard your choices.", style: TextStyle(color: Colors.brown, fontSize: 12, fontWeight: FontWeight.w600, height: 1.3))),
                 ],
               ),
             ),

          const SizedBox(height: 10),
          
          // The "Submit Preferences" button is visible to BOTH Host and Guest until they finalize.
          if (!vm.hasSubmitted) ...[
            AuthButton(
              text: "Submit Preferences",
              onPressed: () async {
                await vm.submitPreference();
                if (mounted) {
                  if (vm.errorMessage != null) _showSnackBar(vm.errorMessage!, isError: true);
                  else _showSnackBar("Preferences Submitted!", isError: false);
                }
              },
            ),
            const SizedBox(height: 20), 
          ],
          
          // The "Generate Recommendations" button is uniquely reserved for the Host.
          if (vm.isHost) ...[
            AuthButton(
              text: "Generate Recommendations",
              onPressed: () async {
                await vm.generateRecommendation();
                if (mounted && vm.errorMessage != null) {
                  _showSnackBar(vm.errorMessage!, isError: true);
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  /// Renders the interactive RangeSlider for setting a budget limit.
  Widget _buildBudgetCard(RoomViewModel vm) {
    return AuthBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("Budget Range"),
          const SizedBox(height: 5),
          Center(
            child: Text(
              "\$${vm.budgetRange.start.round()}  —  \$${vm.budgetRange.end.round()}",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: kPrimaryColor),
            ),
          ),
          const SizedBox(height: 5),
          RangeSlider(
            values: vm.budgetRange,
            min: 0,
            max: 250, 
            divisions: 50, 
            activeColor: kPrimaryColor,
            inactiveColor: Colors.grey.shade200,
            labels: RangeLabels("\$${vm.budgetRange.start.round()}", "\$${vm.budgetRange.end.round()}"),
            onChanged: vm.isLocked ? null : (RangeValues values) {
              vm.updateBudget(values);
            },
          ),
        ],
      ),
    );
  }

  /// Renders a passive waiting screen for Guests who have already submitted their votes.
  Widget _buildWaitingScreen(RoomViewModel vm) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const CircularProgressIndicator(color: kPrimaryColor),
        const SizedBox(height: 20),
        const Text("Waiting for the Host...", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(color: kPrimaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(30)),
          child: Text("Room ID: ${vm.roomId}", style: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold)),
        )
      ]),
    );
  }

  /// Renders the top card showing the user's role and the copyable room ID.
  Widget _buildRoomIdentityCard(RoomViewModel vm) {
    final bool isHost = vm.isHost;
    final Color roleColor = isHost ? Colors.amber.shade700 : Colors.blue.shade600;

    return AuthBox(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: roleColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Text(isHost ? "👑 HOST" : "👤 GUEST", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: roleColor)),
          ),
          const SizedBox(height: 15),
          const Text("Active Room", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 15),
          GestureDetector(
            onTap: () => _copyToClipboard(vm.roomId),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(color: kPrimaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(30)),
              child: Row(
                mainAxisSize: MainAxisSize.min, 
                children: [
                  Text("ID: ${vm.roomId}", style: const TextStyle(fontWeight: FontWeight.bold, color: kPrimaryColor)), 
                  const SizedBox(width: 10), 
                  const Icon(Icons.copy, size: 18, color: kPrimaryColor)
                ]
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            width: double.infinity,
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
            child: Column(
              children: [
                Text(
                  isHost 
                      ? "You are the Host.\nWait for guests to submit, then click Generate." 
                      : "Submit preferences & budget",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w500)
                ),
                const SizedBox(height: 8),
                const Text("Click 'Home' below to return safely", style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Displays the dynamically hydrated list of users who have successfully submitted preferences.
  Widget _buildSubmittedPreferencesHeader(RoomViewModel vm) {
    return AuthBox(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text("Submitted Preferences", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          // Hardcoded max of 12 for UI purposes based on current app specs
          Text("${vm.submittedCount}/12", style: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold, fontSize: 18)),
        ]),
        const SizedBox(height: 10),
        if (vm.submittedCount == 0) 
          const Text("Waiting for submissions...", style: TextStyle(color: Colors.grey))
        else 
          Wrap(
            spacing: 8, 
            runSpacing: 8,
            // STRICT TYPING APPLIED HERE to ensure Flutter builds the widget tree correctly
            children: vm.submittedUsers.map<Widget>((user) {
              final bool isHostIcon = user['isHost'] == true; 
              final String username = user['username']?.toString() ?? "Guest";
              
              return Chip(
                avatar: CircleAvatar(
                  backgroundColor: isHostIcon ? Colors.amber.shade600 : Colors.green, 
                  child: const Icon(Icons.check, color: Colors.white, size: 12)
                ), 
                label: Text(
                  username, 
                  style: TextStyle(
                    color: isHostIcon ? Colors.amber.shade900 : Colors.black87,
                    fontWeight: isHostIcon ? FontWeight.bold : FontWeight.normal
                  )
                ), 
                backgroundColor: isHostIcon ? Colors.amber.shade50 : const Color(0xFFE8F5E9),
                side: BorderSide.none,
              );
            }).toList(),
          ),
      ]),
    );
  }

  /// Renders the list of preferences the user is currently building locally.
  Widget _buildLivePreferencesSection(BuildContext context, RoomViewModel vm) {
    return AuthBox(
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text("Live Preferences (${vm.preferenceCount}/3)", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          // Only show the Add button if the user is not locked out (hasn't submitted)
          if (!vm.isLocked) IconButton(icon: const Icon(Icons.add_circle, color: kPrimaryColor, size: 30), onPressed: () => _handleAddButtonPress(vm)),
        ]),
        const Divider(),
        
        // UX FIX: If they already submitted but local state is empty (e.g., they re-entered the room)
        if (vm.isLocked && vm.allPreferences.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10.0),
            child: Text("Your preferences are submitted. ✅", style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600, fontSize: 14)),
          )
        // Default empty state before submission
        else if (vm.allPreferences.isEmpty) 
          const Text("No choices added.", style: TextStyle(color: Colors.grey))
        // Show the active or locked list
        else ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(), // Disables inner scrolling to flow with the outer view
          itemCount: vm.allPreferences.length,
          itemBuilder: (ctx, i) {
            final prefName = vm.allPreferences[i];
            // Identify type for icon rendering
            final isRestaurant = vm.selectedRestaurants.any((r) => r['name'] == prefName);

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 4, offset: const Offset(0, 2))],
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: isRestaurant ? Colors.blue.shade50 : Colors.orange.shade50, shape: BoxShape.circle),
                  child: Icon(isRestaurant ? Icons.store_rounded : Icons.restaurant_menu_rounded, color: isRestaurant ? Colors.blue : kPrimaryColor, size: 20),
                ),
                title: Text(prefName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                // Trailing remove button vanishes once the user locks in their submission
                trailing: vm.isLocked ? null : IconButton(icon: const Icon(Icons.close, color: Colors.grey, size: 20), onPressed: () => vm.removePreferenceByName(prefName)),
              ),
            );
          },
        )
      ]),
    );
  }
}

/// ==============================================================================
/// GOOGLE MAP SEARCH DIALOG
/// ==============================================================================
/// A self-contained stateful widget that encapsulates the Google Maps experience.
/// It queries the backend proxy (to avoid CORS) and plots markers on the map.
class _GoogleMapSearchDialog extends StatefulWidget {
  final RoomViewModel vm;
  const _GoogleMapSearchDialog({required this.vm});
  @override
  State<_GoogleMapSearchDialog> createState() => _GoogleMapSearchDialogState();
}

class _GoogleMapSearchDialogState extends State<_GoogleMapSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Map<String, dynamic>? _selectedPlace;
  bool _isSearching = false;

  /// Triggered when the user hits the Search button.
  /// Calls the ViewModel, which passes the query to the backend Cloud Run service.
  void _onSearch() async {
    FocusScope.of(context).unfocus(); // Drops the mobile keyboard
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    
    setState(() => _isSearching = true);
    
    final results = await widget.vm.searchPlaces(query);
    if (!mounted) return;
    
    // Fallback if the API returns zero hits
    if (results.isEmpty) { 
      setState(() => _isSearching = false); 
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No results found."))); 
      return; 
    }
    
    // Success: Populate the map with pins and select the primary result
    setState(() {
      _isSearching = false;
      _selectedPlace = results.first;
      
      _markers = results.map((place) => Marker(
        markerId: MarkerId(place['placeId']),
        position: LatLng(place['lat'], place['lng']),
        onTap: () => setState(() => _selectedPlace = place),
      )).toSet();
    });
    
    // Pan the camera gracefully to the discovered coordinate
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(_selectedPlace!['lat'], _selectedPlace!['lng']), 15.0));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        height: 600, 
        child: Stack(
          children: [
            // Map Layer
            ClipRRect(
              borderRadius: BorderRadius.circular(20), 
              child: GoogleMap(
                initialCameraPosition: const CameraPosition(target: LatLng(3.1390, 101.6869), zoom: 12), // Default center (Kuala Lumpur)
                onMapCreated: (c) => _mapController = c, 
                markers: _markers
              )
            ),
            
            // Search Overlay Layer
            Positioned(
              top: 20, left: 15, right: 15,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white, 
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [const BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))]
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: "Enter restaurant name...",
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        prefixIcon: Icon(Icons.search, color: Colors.grey),
                      ),
                      textInputAction: TextInputAction.done, 
                    ),
                  ),
                  
                  const SizedBox(height: 10),
                  
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryColor,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14)
                    ),
                    onPressed: _isSearching ? null : _onSearch,
                    child: _isSearching 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                        : const Text("Search Restaurant", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              )
            ),
            
            // Floating Action Selection Layer (Pops up when a pin is tapped)
            if (_selectedPlace != null) 
              Positioned(
                bottom: 25, left: 25, right: 25, 
                child: AuthButton(
                  text: "Select: ${_selectedPlace!['name']}", 
                  onPressed: () => Navigator.pop(context, _selectedPlace)
                )
              )
          ],
        ),
      ),
    );
  }
}