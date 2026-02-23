import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../viewmodels/room_vm.dart';
import 'common_widgets.dart'; 
import 'bottom_nav.dart'; 

/// ==============================================================================
/// ROOM PAGE
/// ==============================================================================
/// The central hub for the collaborative group dining session.
/// 
/// This widget acts as the primary view for both the "Host" and the "Guests".
/// It listens to a live Firestore stream to update its UI across three main states:
/// 1. **Lobby State**: Users are adding and submitting preferences.
/// 2. **Processing State**: The AI is currently generating a recommendation.
/// 3. **Verdict State**: The final AI recommendation is displayed to all users.
class RoomPage extends StatefulWidget {
  const RoomPage({super.key});

  @override
  State<RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends State<RoomPage> {
  
  /// --------------------------------------------------------------------------
  /// LIFECYCLE
  /// --------------------------------------------------------------------------
  
  /// Initializes the state and captures the room ID passed via routing arguments.
  @override
  void initState() {
    super.initState();
    // Execute after the first frame is rendered to ensure BuildContext is fully available.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final String? roomId = ModalRoute.of(context)?.settings.arguments as String?;
      if (roomId != null && roomId.isNotEmpty) {
        context.read<RoomViewModel>().init(roomId);
      }
    });
  }

  /// --------------------------------------------------------------------------
  /// UI HELPERS
  /// --------------------------------------------------------------------------
  
  /// Displays a floating SnackBar at the bottom of the screen for user feedback.
  /// 
  /// [message] The text to display.
  /// [isError] If true, displays a red background indicating failure. Otherwise, green for success.
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

  /// --------------------------------------------------------------------------
  /// NAVIGATION GUARD
  /// --------------------------------------------------------------------------
  /// Intercepts bottom navigation taps to prevent users from accidentally 
  /// leaving the room and losing unsubmitted data.
  /// 
  /// [index] The index of the tapped bottom navigation bar item.
  Future<void> _onBottomNavTap(int index) async {
    final vm = context.read<RoomViewModel>();
    
    // 1. Host/Lock Validation
    bool isAllowed = vm.validateNavigation(index);
    if (!isAllowed) {
      if (vm.errorMessage != null) _showSnackBar(vm.errorMessage!, isError: true);
      return;
    }

    // 2. Unsubmitted Preferences Guard
    // Triggers a confirmation dialog if a guest has pending edits.
    if (!vm.isHost && !vm.isLocked && vm.preferenceCount > 0) {
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
                onPressed: () => Navigator.pop(ctx, false) 
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text("Leave & Discard"), 
                onPressed: () => Navigator.pop(ctx, true) 
              ),
            ]
        )
      ) ?? false;
      
      if (!confirmLeave) return; 
    }

    // 3. Cleanup & Navigate
    vm.clearLocalPreferences(); 

    if (!mounted) return;
    
    if (index == 1) Navigator.pushReplacementNamed(context, '/home');
    else if (index == 0) Navigator.pushReplacementNamed(context, '/home'); 
    else if (index == 2) Navigator.pushReplacementNamed(context, '/settings');
  }

  /// Copies the provided Room ID to the device's clipboard.
  /// [id] The 6-character room identifier.
  void _copyToClipboard(String id) {
    Clipboard.setData(ClipboardData(text: id));
    _showSnackBar('Room ID copied!', isError: false);
  }

  /// --------------------------------------------------------------------------
  /// PREFERENCE ADDITION FLOW
  /// --------------------------------------------------------------------------
  /// Triggers the multi-step flow for a guest to add a new food preference.
  /// 
  /// Sequence: 
  /// 1. Limit Check (Max 3).
  /// 2. Select Category (Restaurant or Cuisine).
  /// 3. Open Specific Picker Dialog (Google Maps or Chip List).
  /// 4. Save to ViewModel.
  /// 
  /// [vm] The active RoomViewModel instance.
  void _handleAddButtonPress(RoomViewModel vm) async {
    if (vm.isHost) return;
    if (vm.preferenceCount >= RoomViewModel.MAX_PREFS) {
      _showSnackBar("You can only choose up to 3 preferences!", isError: true);
      return;
    }

    String? type = await _showTypeSelectionDialog();
    if (type == null || !mounted) return;

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

  /// --------------------------------------------------------------------------
  /// DIALOG WIDGETS
  /// --------------------------------------------------------------------------
  
  /// Displays a dialog asking the user to pick between "Restaurant" and "Cuisine".
  /// Returns the selected string, or null if dismissed.
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

  /// Displays a predefined list of popular cuisines as selectable chips.
  /// Returns the selected cuisine string, or null if dismissed.
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

  /// Helper widget to build the large square buttons used in the Type Selection Dialog.
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

  /// Standardizes the header layout for grouped sections within the room lobby.
  Widget _buildSectionHeader(String title, {Widget? action}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
        if (action != null) action,
      ],
    );
  }

  /// --------------------------------------------------------------------------
  /// MAIN BUILD METHOD
  /// --------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RoomViewModel>();

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: const Text("Room", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent, 
        elevation: 0, 
        automaticallyImplyLeading: false, 
      ),
      
      body: vm.roomId.isEmpty 
          ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('rooms').doc(vm.roomId).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));

                final data = snapshot.data!.data() as Map<String, dynamic>?;
                if (data == null) return const Center(child: Text("Room ended."));

                // Push new stream data to ViewModel
                WidgetsBinding.instance.addPostFrameCallback((_) {
                   if (mounted) vm.updateFromStream(data); 
                });

                // STATE A: VERDICT AVAILABLE
                if (data.containsKey('output')) {
                  final output = data['output'];
                  if (output is Map && output.isNotEmpty) {
                      return _buildResultViewFromMap(Map<String, dynamic>.from(output));
                  }
                }

                // STATE B: PROCESSING
                String status = data['status'] ?? 'waiting';
                if (status == 'processing') {
                  return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    CircularProgressIndicator(color: kPrimaryColor),
                    SizedBox(height: 20),
                    Text("AI is deciding...", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kPrimaryColor))
                  ]));
                }
                
                // STATE C: LOBBY
                return _buildBodyContent(vm);
              },
            ),
      
      bottomNavigationBar: CustomBottomNav(
        currentIndex: 1, 
        onTap: _onBottomNavTap,
      ),
    );
  }

  /// --------------------------------------------------------------------------
  /// STATE A: RESULT VIEW (THE VERDICT)
  /// --------------------------------------------------------------------------
  /// Parses the AI output payload and presents it as a polished, standalone screen.
  /// [result] The raw Map object constructed from the Firestore output field.
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

  /// --------------------------------------------------------------------------
  /// STATE C: LOBBY CONTENT
  /// --------------------------------------------------------------------------
  
  /// Builds the main layout for the room while it is waiting for users to submit.
  Widget _buildBodyContent(RoomViewModel vm) {
    if (!vm.isHost && vm.isLocked) return _buildWaitingScreen(vm);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildRoomIdentityCard(vm),
          const SizedBox(height: 20),
          
          if (!vm.isHost) ...[
            _buildBudgetCard(vm),
            const SizedBox(height: 20),
          ],

          _buildSubmittedPreferencesHeader(vm),
          const SizedBox(height: 20),
          
          if (!vm.isHost) ...[
            _buildLivePreferencesSection(context, vm),
            
            if (vm.preferenceCount > 0 && !vm.isLocked)
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
            
            AuthButton(
              text: "Submit Preferences",
              onPressed: () async {
                await vm.submitPreference();
                if (mounted) {
                  if (vm.errorMessage != null) _showSnackBar(vm.errorMessage!, isError: true);
                  else if (vm.isLocked) _showSnackBar("Preferences Submitted!", isError: false);
                }
              },
            ),
          ] else ...[
            const SizedBox(height: 40),
            
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

  /// Displays the interactive RangeSlider for Guests to set their budget bounds.
  /// Binds directly to `vm.updateBudget()` to modify ViewModel state.
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
            // Nullifying onChanged disables the slider if the user is locked out.
            onChanged: vm.isLocked ? null : (RangeValues values) {
              vm.updateBudget(values);
            },
          ),
        ],
      ),
    );
  }

  /// An intermediate screen shown to Guests after they hit 'Submit'.
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

  /// The top card detailing the user's role (Host/Guest) and the shareable Room ID.
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
                  isHost ? "You are the Host.\nWait for guests to submit, then click Generate." : "Submit preferences & budget",
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

  /// Displays the count and identity chips of all participants who have successfully submitted.
  Widget _buildSubmittedPreferencesHeader(RoomViewModel vm) {
    return AuthBox(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text("Submitted Preferences", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text("${vm.submittedCount}/12", style: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold, fontSize: 18)),
        ]),
        const SizedBox(height: 10),
        if (vm.submittedCount == 0) 
          const Text("Waiting for submissions...", style: TextStyle(color: Colors.grey))
        else 
          Wrap(
            spacing: 8, 
            runSpacing: 8,
            children: List.generate(vm.submittedCount, (i) {
              final bool isHost = i == 0; 
              
              return Chip(
                avatar: CircleAvatar(
                  backgroundColor: isHost ? Colors.amber.shade600 : Colors.green, 
                  child: const Icon(Icons.check, color: Colors.white, size: 12)
                ), 
                label: Text(
                  isHost ? "Host" : "Guest", 
                  style: TextStyle(
                    color: isHost ? Colors.amber.shade900 : Colors.black87,
                    fontWeight: isHost ? FontWeight.bold : FontWeight.normal
                  )
                ), 
                backgroundColor: isHost ? Colors.amber.shade50 : const Color(0xFFE8F5E9),
                side: BorderSide.none,
              );
            }),
          ),
      ]),
    );
  }

  /// Displays the user's currently selected preferences (Restaurants and Cuisines)
  /// before they are submitted to the database. Contains logic to differentiate 
  /// between the two types for custom UI icons.
  Widget _buildLivePreferencesSection(BuildContext context, RoomViewModel vm) {
    return AuthBox(
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text("Live Preferences (${vm.preferenceCount}/3)", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          if (!vm.isLocked) IconButton(icon: const Icon(Icons.add_circle, color: kPrimaryColor, size: 30), onPressed: () => _handleAddButtonPress(vm)),
        ]),
        const Divider(),
        if (vm.allPreferences.isEmpty) const Text("No choices added.", style: TextStyle(color: Colors.grey))
        else ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(), 
          itemCount: vm.allPreferences.length,
          itemBuilder: (ctx, i) {
            final prefName = vm.allPreferences[i];
            
            // Evaluates if the specific string maps to a stored Restaurant object.
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
/// GOOGLE MAPS SEARCH DIALOG
/// ==============================================================================
/// A stateful dialog containing an interactive Google Map and a text field.
/// Allows users to search for specific physical restaurants via the Places API,
/// preview their location on the map, and confirm their selection.
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

  /// Executes the text query against the Coordinator's map service.
  /// Updates the map with interactive markers if results are found.
  void _onSearch() async {
    FocusScope.of(context).unfocus(); 
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    
    setState(() => _isSearching = true);
    
    final results = await widget.vm.searchPlaces(query);
    if (!mounted) return;
    
    if (results.isEmpty) { 
      setState(() => _isSearching = false); 
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No results found."))); 
      return; 
    }
    
    setState(() {
      _isSearching = false;
      _selectedPlace = results.first;
      
      _markers = results.map((place) => Marker(
        markerId: MarkerId(place['placeId']),
        position: LatLng(place['lat'], place['lng']),
        onTap: () => setState(() => _selectedPlace = place),
      )).toSet();
    });
    
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
            // 1. The Interactive Map Layer
            ClipRRect(
              borderRadius: BorderRadius.circular(20), 
              child: GoogleMap(
                initialCameraPosition: const CameraPosition(target: LatLng(3.1390, 101.6869), zoom: 12), 
                onMapCreated: (c) => _mapController = c, 
                markers: _markers
              )
            ),
            
            // 2. The Floating Search Input Overlay
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
            
            // 3. The Selection Confirmation Overlay 
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