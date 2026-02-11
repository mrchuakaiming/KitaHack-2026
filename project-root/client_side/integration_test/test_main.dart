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
import 'store_recommendation_test.dart';
import 'want_result_test.dart';
import 'delete_account_test.dart';

Future<void> main() async {
  // 1️⃣ Enable integration test binding
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // 2️⃣ Initialize Firebase (without firebase_options.dart)
  await Firebase.initializeApp();

  // 3️⃣ Connect Firebase SDKs to emulators
  // ⚠️ Use '10.0.2.2' for Android emulator; 'localhost' for iOS/macOS
  const host = String.fromEnvironment('FIREBASE_EMULATOR_HOST', defaultValue: 'localhost');

  FirebaseAuth.instance.useAuthEmulator(host, 9099);
  FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
  FirebaseDatabase.instance.useDatabaseEmulator(host, 9000);

  // 4️⃣ Register all test suites
  registerUserTests();
  loginUserTests();
  newRoomTests();
  joinRoomTests();
  submitPreferenceTests();
  leaveRoomTests();
  storeRecommendationTests();
  wantResultTests();
  deleteAccountTests();
}
