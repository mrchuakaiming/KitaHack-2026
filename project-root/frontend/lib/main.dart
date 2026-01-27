// main.dart is used as the program's main entry point by starting the What2Eat app.
import 'package:flutter/material.dart';
import 'app.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'What2Eat',
      debugShowCheckedModeBanner: false,
      
      // --- THEME SETTINGS ---
      theme: ThemeData(
        // The Primary "Brand" Color
        primaryColor: const Color(0xFFFF7043),
        
        // Background color of all pages
        scaffoldBackgroundColor: const Color(0xFFF9F9F9),
        
        // Define the default color scheme
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF7043),
          primary: const Color(0xFFFF7043), // Orange for active elements
          secondary: const Color(0xFF424242), // Dark Grey for accents
        ),

        // Global AppBar Style (Clean & Flat)
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent, // See-through
          elevation: 0, // No shadow
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Color(0xFF212121), // Dark text
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontFamily: 'Arial', // Fallback font
          ),
          iconTheme: IconThemeData(color: Color(0xFF212121)),
        ),
        
        useMaterial3: true,
      ),
      
      // Load routes from app.dart
      initialRoute: '/login',
      routes: AppRoutes.routes,
    );
  }
}
