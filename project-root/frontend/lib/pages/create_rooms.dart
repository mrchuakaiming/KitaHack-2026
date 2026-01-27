import 'package:flutter/material.dart';
import '../widgets/custom_bottom_nav.dart';

class CreateRoomPage extends StatelessWidget {
  const CreateRoomPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create a Room")),
      body: const Center(child: Text("Create Room Page Content")),
      bottomNavigationBar: const CustomBottomNav(currentIndex: 0), // Index 0 is Create
    );
  }
}