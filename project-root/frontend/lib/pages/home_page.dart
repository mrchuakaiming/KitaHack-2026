import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../widgets/common_widgets.dart';
import '../widgets/custom_bottom_nav.dart';
import '../viewmodels/home_vm.dart';
import '../viewmodels/room_vm.dart';

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
      SnackBar(content: Text('Copied $code'), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    final homeVM = context.watch<HomeViewModel>();
    final roomVM = context.watch<RoomViewModel>(); // Watch for loading state

    return Scaffold(
      appBar: AppBar(
        title: const Text("What2Eat", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Join room", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            
            AuthBox(
              child: Column(
                children: [
                  AuthTextField(
                    labelText: "Enter Room Code",
                    obscureText: false,
                    controller: _roomCodeController,
                    prefixIcon: const Icon(Icons.vpn_key),
                    validator: (_) => homeVM.joinError,
                  ),
                  const SizedBox(height: 15),
                  
                  AuthButton(
                    text: roomVM.isLoading ? "Joining..." : "Join",
                    onPressed: () async {
                      final code = _roomCodeController.text;
                      // 1. Validate Input (HomeVM)
                      if (homeVM.validateCode(code)) {
                        // 2. Perform Join (RoomVM)
                        bool success = await context.read<RoomViewModel>().joinRoom(code);
                        if (success && mounted) {
                          Navigator.pushNamed(context, '/room');
                        }
                      }
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
            const Text("Rooms you host", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),

            ...homeVM.hostedRooms.map((room) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 5)],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(room.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 5),
                      Text("Code: ${room.code}", style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, color: kPrimaryColor),
                    onPressed: () => _copyToClipboard(room.code),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
      bottomNavigationBar: const CustomBottomNav(currentIndex: 1),
    );
  }
}