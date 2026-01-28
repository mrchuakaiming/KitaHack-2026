// main.dart is used as the program's main entry point by starting the What2Eat app.
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'app.dart';
import 'viewmodels/home_vm.dart';
import 'viewmodels/room_vm.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // The Dashboard State
        ChangeNotifierProvider(create: (_) => HomeViewModel()),
        
        // The Shared Room State
        ChangeNotifierProvider(create: (_) => RoomViewModel()),
      ],
      child: MaterialApp(
        title: 'What2Eat',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primaryColor: const Color(0xFFFF7043),
          scaffoldBackgroundColor: const Color(0xFFF9F9F9),
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF7043)),
          useMaterial3: true,
        ),
        initialRoute: '/login',
        routes: AppRoutes.routes,
      ),
    );
  }
}