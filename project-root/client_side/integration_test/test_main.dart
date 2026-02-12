/*
  (macOS/Linux)
  chromedriver --port=4444

  (windows)
  chromedriver.exe --port=4444

  Run:
  flutter drive \
  --driver=integration_test/driver.dart \
  --target=integration_test/test_main.dart \
  -d chrome
*/

// integration_test/test_main.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

// --------------------
// Import test suites
// --------------------
import 'register_user_test.dart';
import 'login_user_test.dart';
import 'new_room_test.dart';
import 'join_room_test.dart';
import 'submit_preference_test.dart';
import 'leave_room_test.dart';
import 'generate_recommendation_test.dart';
import 'store_recommendation_test.dart';
import 'want_result_test.dart';
import 'delete_account_test.dart';

Future<void> main() async {
  // Enable integration test binding
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (without firebase_options.dart)
  await Firebase.initializeApp();

  // Connect Firebase SDKs to emulators
  const host = String.fromEnvironment('FIREBASE_EMULATOR_HOST', defaultValue: 'localhost');
  
  FirebaseAuth.instance.useAuthEmulator(host, 9099);
  FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
  FirebaseDatabase.instance.useDatabaseEmulator(host, 9000);

  // Register all test suites
  registerUserTests();
  loginUserTests();
  newRoomTests();
  joinRoomTests();
  submitPreferenceTests();
  leaveRoomTests();
  generateRecommendationTests();
  storeRecommendationTests();
  wantResultTests();
  deleteAccountTests();
}
