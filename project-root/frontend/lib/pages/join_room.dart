import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  // --- Logic Helpers ---

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
          content: Text("You must leave the room first by clicking the Home button."),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // --- DIALOG LOGIC (FIXED & FLATTENED) ---

  // 1. The Main Coordinator Function
  void _handleAddButtonPress() async {
    // Step 1: Ask "Restaurant or Cuisine?"
    String? selectionType = await _showTypeSelectionDialog();

    if (selectionType == null) return; // User cancelled

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
        _livePreferences.add(finalResult!); // <--- The '!' Fix is here
      });
    }
  }

  // Dialog A: Selection Type
  Future<String?> _showTypeSelectionDialog() {
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Add Preference"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("What would you like to suggest?"),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildBigSelectionButton(
                      icon: Icons.store,
                      label: "Restaurant",
                      onTap: () => Navigator.pop(context, 'Restaurant'),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildBigSelectionButton(
                      icon: Icons.restaurant_menu,
                      label: "Cuisine",
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

  // Dialog B: Google Maps Placeholder
  Future<String?> _showGoogleMapsDialog() {
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          contentPadding: EdgeInsets.zero,
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: Stack(
              children: [
                Container(
                  color: Colors.grey.shade300,
                  alignment: Alignment.center,
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.map, size: 50, color: Colors.grey),
                      SizedBox(height: 10),
                      Text("Google Maps API Embedded Here", style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 20, left: 20, right: 20,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                    onPressed: () {
                      Navigator.pop(context, "Restaurant: Burger King (Demo)");
                    },
                    child: const Text("Select This Location (Demo)"),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  // Dialog C: Cuisine Input
  Future<String?> _showCuisineInputDialog() {
    final TextEditingController controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Choose Cuisine"),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: "e.g. Italian, Sushi"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  Navigator.pop(context, "Cuisine: ${controller.text}");
                }
              },
              child: const Text("Add"),
            ),
          ],
        );
      },
    );
  }

  // Helper Widget for the big buttons
  Widget _buildBigSelectionButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
          boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 5, offset: const Offset(0, 3))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.black),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Join Room", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false, 
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header & ID
            Center(
              child: Column(
                children: [
                  Text(widget.roomName, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("ID: ${widget.roomId}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _copyToClipboard,
                          child: const Icon(Icons.copy, size: 18, color: Colors.blue),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Instruction Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                border: Border.all(color: Colors.orange.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "To leave the room, click the Home button below.",
                      style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 20),

            // 2. Budget Slider
            const Text("Your Budget Range", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("\$${_budgetRange.start.round()}", style: const TextStyle(fontSize: 16)),
                Text("\$${_budgetRange.end.round()}", style: const TextStyle(fontSize: 16)),
              ],
            ),
            RangeSlider(
              values: _budgetRange,
              min: 0,
              max: 100,
              divisions: 20,
              activeColor: Colors.black,
              inactiveColor: Colors.grey.shade300,
              labels: RangeLabels("\$${_budgetRange.start.round()}", "\$${_budgetRange.end.round()}"),
              onChanged: _isLocked ? null : (RangeValues values) {
                setState(() {
                  _budgetRange = values;
                });
              },
            ),

            const SizedBox(height: 30),

            // 3. Live Preferences
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Live Preferences", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                if (!_isLocked)
                  IconButton(
                    icon: const Icon(Icons.add_circle, size: 30, color: Colors.black),
                    // FIXED: Wrapped in lambda to avoid type errors
                    onPressed: () => _handleAddButtonPress(), 
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // LIST VIEW OF PREFERENCES
            if (_livePreferences.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: const Text("No preferences added yet.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _livePreferences.length,
                itemBuilder: (context, index) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.black12),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 4, offset: const Offset(0, 2))],
                    ),
                    child: ListTile(
                      leading: Icon(
                        _livePreferences[index].contains("Restaurant") ? Icons.store : Icons.restaurant_menu,
                        color: Colors.black54,
                      ),
                      title: Text(_livePreferences[index], style: const TextStyle(fontWeight: FontWeight.w500)),
                      trailing: _isLocked ? null : IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _removePreference(index),
                      ),
                    ),
                  );
                },
              ),

            const SizedBox(height: 40),

            // 4. Done Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isLocked ? Colors.grey : Colors.green,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isLocked ? null : _lockSelection,
                child: Text(
                  _isLocked ? "Waiting for others..." : "Done",
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
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