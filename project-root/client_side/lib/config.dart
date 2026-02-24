import 'package:flutter/foundation.dart';

class Config {
  // 1. Production URL (UPDATED to Singapore)
  static const String _prodUrl = "https://api-rkm6axkdcq-as.a.run.app";

  // 2. Localhost (Updated region for Emulator/Web)
  // Note: The emulator will now host at /asia-southeast1/ because your python code specifies it.
  static const String _localUrl = "http://127.0.0.1:5001/what2eat-1469f/asia-southeast1/api";

  // 3. Android Emulator (Special IP for local dev)
  static const String _androidUrl = "http://10.0.2.2:5001/what2eat-1469f/asia-southeast1/api";

  /// Dynamic Getter to serve the correct URL based on the device/mode.
  static String get serverBaseUrl {
    // If built for production (flutter build web --release), use the live server
    if (kReleaseMode) {
      return _prodUrl;
    }

    // --- FOR TESTING PRODUCTION LOCALLY ---
    // Uncomment this if you want to test the LIVE backend while running locally
    // return _prodUrl; 

    // If running on Web (Debug mode)
    if (kIsWeb) {
      return _localUrl;
    }

    // If running on Android Emulator
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _androidUrl;
    }

    // Default (iOS Simulator, Desktop)
    return _localUrl;
  }
}