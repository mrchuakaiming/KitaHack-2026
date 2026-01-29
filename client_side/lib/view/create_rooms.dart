// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart'; // For Clipboard
// import 'package:provider/provider.dart';
// import '../widgets/common_widgets.dart';
// import '../widgets/custom_bottom_nav.dart';
// import '../viewmodels/room_vm.dart';

// class CreateRoomPage extends StatelessWidget {
//   final TextEditingController _nameController = TextEditingController();

//   CreateRoomPage({super.key});

//   void _showSuccessDialog(BuildContext context, String roomId, String roomName) {
//     showDialog(
//       context: context,
//       barrierDismissible: false, // User must click close
//       builder: (ctx) => AlertDialog(
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//         title: const Column(
//           children: [
//             Icon(Icons.check_circle, color: Colors.green, size: 50),
//             SizedBox(height: 10),
//             Text("Room Created!", style: TextStyle(fontWeight: FontWeight.bold)),
//           ],
//         ),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Text("Room: $roomName"),
//             const SizedBox(height: 15),
//             Container(
//               padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
//               decoration: BoxDecoration(
//                 color: Colors.grey.shade100,
//                 borderRadius: BorderRadius.circular(10),
//                 border: Border.all(color: Colors.grey.shade300),
//               ),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Text(roomId, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
//                   IconButton(
//                     icon: const Icon(Icons.copy, color: kPrimaryColor),
//                     onPressed: () {
//                       Clipboard.setData(ClipboardData(text: roomId));
//                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ID Copied!")));
//                     },
//                   )
//                 ],
//               ),
//             ),
//             const SizedBox(height: 10),
//             const Text("Share this code with your friends.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () {
//               Navigator.pop(ctx); // Close dialog
//               // We stay on CreateRoomPage, as requested. 
//               // If you want to clear the field:
//               // _nameController.clear();
//             }, 
//             child: const Text("Close"),
//           ),
//           ElevatedButton(
//             style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
//             onPressed: () {
//               Navigator.pop(ctx);
//               Navigator.pushReplacementNamed(context, '/room'); // Or join immediately if they want
//             },
//             child: const Text("Enter Room", style: TextStyle(color: Colors.white)),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final roomVM = context.watch<RoomViewModel>();

//     return Scaffold(
//       appBar: AppBar(title: const Text("Create Room")),
//       body: Padding(
//         padding: const EdgeInsets.all(20.0),
//         child: Column(
//           children: [
//             const AuthHeader(title: "New Room", subtitle: "Generate a code for your group."),
//             AuthBox(
//               child: Column(
//                 children: [
//                   AuthTextField(
//                     labelText: "Room Name",
//                     obscureText: false,
//                     controller: _nameController,
//                     prefixIcon: const Icon(Icons.meeting_room),
//                   ),
//                   const SizedBox(height: 20),
//                   AuthButton(
//                     text: roomVM.isLoading ? "Creating..." : "Generate Room ID",
//                     onPressed: () async {
//                       if (_nameController.text.isNotEmpty) {
//                         // We now get the String ID back!
//                         String? newId = await roomVM.createRoom(_nameController.text);
                        
//                         if (newId != null && context.mounted) {
//                           // Show the dialog instead of navigating
//                           _showSuccessDialog(context, newId, _nameController.text);
//                         }
//                       }
//                     },
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//       bottomNavigationBar: const CustomBottomNav(currentIndex: 0),
//     );
//   }
// }