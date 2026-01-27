import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import '../widgets/common_widgets.dart'; // Uses your Premium Widgets

class JoinRoomPage extends StatefulWidget {
  final String roomName;
  final String roomId;

  const JoinRoomPage({
    super.key, 
    this.roomName = "Friday Lunch", 
    this.roomId = "A7X-92B"
  });

  @override
  State<JoinRoomPage> createState() => _JoinRoomPageState();
}

class _JoinRoomPageState extends State<JoinRoomPage> {
  // State
  RangeValues _budgetRange = const RangeValues(10, 50); 
  final List<String> _livePreferences = []; 
  bool _isLocked = false; 

  // --- Logic Helpers (Preserved) ---

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: widget.roomId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Room ID ${widget.roomId} copied!'), duration: const Duration(seconds: 1)),
    );
  }

  void _removePreference(int index) {
    setState(() {
      _livePreferences.removeAt(index);
    });
  }

  void _lockSelection() {
    setState(() {
      _isLocked = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Preferences submitted! Waiting for others..."), backgroundColor: Colors.green),
    );
  }

  void _handleBottomNavTap(int index) {
    if (index == 1) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("To leave, please click the Home button."),
          backgroundColor: kPrimaryColor, // Orange warning
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // --- DIALOG LOGIC (PRESERVED) ---

  void _handleAddButtonPress() async {
    // Step 1: Ask "Restaurant or Cuisine?"
    String? selectionType = await _showTypeSelectionDialog();

    if (selectionType == null) return; 
    if (!mounted) return;

    String? finalResult;

    // Step 2: Open the specific dialog
    if (selectionType == 'Restaurant') {
      finalResult = await _showGoogleMapsDialog();
    } else if (selectionType == 'Cuisine') {
      finalResult = await _showCuisineInputDialog();
    }

    // Step 3: Update List
    if (finalResult != null && mounted) {
      setState(() {
        _livePreferences.add(finalResult!);
      });
    }
  }

  // Dialog A: Selection Type (Redesigned)
  Future<String?> _showTypeSelectionDialog() {
    return showDialog<String>(
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
  }

  // Dialog B: Google Maps (Redesigned)
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

  // Dialog C: Cuisine Input (Redesigned)
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

  // Helper Widget for the big dialog buttons
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

  // Helper for Section Headers
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
    return Scaffold(
      // Background handled by Theme (Soft Grey)
      appBar: AppBar(
        title: const Text("Lobby", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false, 
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // --- 1. Room Identity Card ---
            AuthBox(
              child: Column(
                children: [
                  Text(widget.roomName, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.black87)),
                  const SizedBox(height: 15),
                  // The "Ticket" ID
                  GestureDetector(
                    onTap: _copyToClipboard,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: kPrimaryColor.withOpacity(0.1), // Light Orange
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: kPrimaryColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("ID: ${widget.roomId}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kPrimaryColor, letterSpacing: 1)),
                          const SizedBox(width: 10),
                          const Icon(Icons.copy, size: 18, color: kPrimaryColor),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Instruction Note
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text("Click 'Home' below to leave safely", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),

            // --- 2. Budget Card ---
            AuthBox(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader("Budget Range"),
                  const SizedBox(height: 5),
                  Center(
                    child: Text(
                      "\$${_budgetRange.start.round()}  —  \$${_budgetRange.end.round()}",
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: kPrimaryColor),
                    ),
                  ),
                  const SizedBox(height: 5),
                  RangeSlider(
                    values: _budgetRange,
                    min: 0,
                    max: 100,
                    divisions: 20,
                    activeColor: kPrimaryColor,
                    inactiveColor: Colors.grey.shade200,
                    labels: RangeLabels("\$${_budgetRange.start.round()}", "\$${_budgetRange.end.round()}"),
                    onChanged: _isLocked ? null : (RangeValues values) {
                      setState(() {
                        _budgetRange = values;
                      });
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // --- 3. Live Preferences Card ---
            AuthBox(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(
                    "Preferences", 
                    action: !_isLocked 
                      ? IconButton(
                          icon: const Icon(Icons.add_circle, size: 32, color: kPrimaryColor),
                          onPressed: () => _handleAddButtonPress(), 
                        )
                      : null,
                  ),
                  
                  const SizedBox(height: 10),

                  if (_livePreferences.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.no_food, color: Colors.grey, size: 30),
                          SizedBox(height: 5),
                          Text("No cravings added yet", style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _livePreferences.length,
                      itemBuilder: (context, index) {
                        final isRestaurant = _livePreferences[index].contains("Restaurant");
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
                              decoration: BoxDecoration(
                                color: isRestaurant ? Colors.blue.shade50 : Colors.orange.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isRestaurant ? Icons.store_rounded : Icons.restaurant_menu_rounded,
                                color: isRestaurant ? Colors.blue : kPrimaryColor,
                                size: 20,
                              ),
                            ),
                            title: Text(_livePreferences[index], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            trailing: _isLocked ? null : IconButton(
                              icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                              onPressed: () => _removePreference(index),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // --- 4. Done Button ---
            AuthButton(
              text: _isLocked ? "Waiting for others..." : "I'm Done",
              onPressed: _isLocked ? () {} : _lockSelection, // Disable click if locked
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
      
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1, 
        onTap: _handleBottomNavTap, 
        backgroundColor: Colors.white,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.lunch_dining), label: 'Create Room'),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}