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

  void _copyToClipboard(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Room code $code copied!'), duration: const Duration(seconds: 1)),
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
            
            // Reusing AuthBox for consistent styling
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
                  AuthButton(
                    text: "Join",
                    onPressed: () {
                      if (_roomCodeController.text.isNotEmpty) {
                        // TODO: Logic to join room
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Joining Room: ${_roomCodeController.text}')),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // --- Section 2: Rooms you host ---
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Lunch with Team", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Text("Code: ", style: TextStyle(color: Colors.grey)),
                          const Text("X92-B41", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
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
      
      // Add the Navigation Bar
      bottomNavigationBar: const CustomBottomNav(currentIndex: 1), // Index 1 is Home
    );
  }
}