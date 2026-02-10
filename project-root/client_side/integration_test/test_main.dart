import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

import 'package:what2eat/firebase_options.dart';

// --------------------
// Import test suites
// --------------------
import 'register_user_test.dart';
// import 'login_user_test.dart';
// import 'delete_user_test.dart';

// --------------------
// main() to run tests
// --------------------
void main() {
  // 1. Enable integration test binding
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // 2. Global setup (async allowed here)
  setUpAll(() async {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Connect Firebase SDKs to emulators
    FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
    FirebaseDatabase.instance.useDatabaseEmulator('localhost', 9000);
  });

  // 3. Run user flow tests
  registerUserTests();
  // loginUserTests();
  // deleteUserTests();
}
