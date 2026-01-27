import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for Clipboard
import '../widgets/common_widgets.dart'; // Reusing your AuthBox logic
import '../widgets/custom_bottom_nav.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _roomCodeController = TextEditingController();

  @override
  void dispose() {
    _roomCodeController.dispose();
    super.dispose();
  }

  // Implementation 1: Clipboard Logic
  void _copyToClipboard(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Room code $code copied!'),
        duration: const Duration(seconds: 1),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("What2Eat", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false, // Hides the back button
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Section 1: Join Room ---
            const Text(
              "Join room",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            
            AuthBox(
              child: Column(
                children: [
                  TextField(
                    controller: _roomCodeController,
                    decoration: const InputDecoration(
                      labelText: "Enter Room Code",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.vpn_key),
                    ),
                  ),
                  const SizedBox(height: 15),
                  
                  // Implementation 2: Navigation to JoinRoomPage
                  AuthButton(
                    text: "Join",
                    onPressed: () {
                      if (_roomCodeController.text.isNotEmpty) {
                        // Pass the entered code to the next page if you want (arguments not shown here for simplicity)
                        Navigator.pushNamed(context, '/join_room'); 
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a room code first'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // --- Section 3: Rooms you host (Preserved) ---
            const Text(
              "Rooms you host",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),

            // Placeholder Room Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Lunch with Team", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      SizedBox(height: 5),
                      Row(
                        children: [
                          Text("Code: ", style: TextStyle(color: Colors.grey)),
                          Text("X92-B41", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, color: Colors.blue),
                    onPressed: () => _copyToClipboard("X92-B41"),
                    tooltip: "Copy Code",
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      
      // Bottom Navigation
      bottomNavigationBar: const CustomBottomNav(currentIndex: 1), // Index 1 is Home
    );
  }
}