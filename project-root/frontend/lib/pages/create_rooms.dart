import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for Clipboard
import 'dart:math'; 
import '../widgets/common_widgets.dart';
import '../widgets/custom_bottom_nav.dart';

class CreateRoomPage extends StatefulWidget {
  const CreateRoomPage({super.key});

  @override
  State<CreateRoomPage> createState() => _CreateRoomPageState();
}

class _CreateRoomPageState extends State<CreateRoomPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _roomNameController = TextEditingController();

  @override
  void dispose() {
    _roomNameController.dispose();
    super.dispose();
  }

  String _generateRoomCode() {
    const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    Random rnd = Random();
    String part1 = String.fromCharCodes(Iterable.generate(
        3, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
    String part2 = String.fromCharCodes(Iterable.generate(
        3, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
    return "$part1-$part2";
  }

  // Helper function to handle copying
  void _copyToClipboard(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Code $code copied to clipboard!'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _handleCreateRoom() {
    if (_formKey.currentState!.validate()) {
      String newCode = _generateRoomCode();

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: const Text("Room Created!"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Share this code with your friends:"),
                const SizedBox(height: 15),
                
                // --- Code + Copy Button Row ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.black, width: 1.5),
                      ),
                      child: Text(
                        newCode,
                        style: const TextStyle(
                          fontSize: 24, 
                          fontWeight: FontWeight.bold, 
                          letterSpacing: 2
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Copy Button
                    IconButton(
                      icon: const Icon(Icons.copy, color: Colors.blue),
                      tooltip: "Copy Code",
                      onPressed: () => _copyToClipboard(newCode),
                    ),
                  ],
                ),
                // -----------------------------
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); 
                  Navigator.pushReplacementNamed(context, '/home'); 
                },
                child: const Text("Go to Lobby", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("What2Eat", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: AuthBox(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Center(
                    child: Text(
                      "Create Room",
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text("Room Name", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  AuthTextField(
                    labelText: "e.g., Friday Lunch",
                    obscureText: false,
                    controller: _roomNameController,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please name your room';
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 30),

                  AuthButton(
                    text: "Create & Invite",
                    onPressed: _handleCreateRoom,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const CustomBottomNav(currentIndex: 0), 
    );
  }
}