import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:what2eat/coordinators/coordinator.dart';
import 'package:what2eat/models/user.dart';

/// Call this from test_main.dart
void registerUserTests() {
  final coordinator = Coordinator();

  group('REGISTER USER — Integration Tests', () {
    setUp(() async {
      // Clear Auth emulator and Firestore before each test
      await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
      await FirebaseAuth.instance.signOut();

      // Delete all users in Auth emulator
      final fi = FirebaseAuth.instance;
      for (final user in fi.currentUser != null ? [fi.currentUser!] : []) {
        await user.delete();
      }

      // Delete Firestore users collection
      final firestore = FirebaseFirestore.instance;
      final users = await firestore.collection('users').get();
      for (final doc in users.docs) {
        await doc.reference.delete();
      }
    });

    // -------------------------------------------------------------
    // 1. SUCCESSFUL REGISTRATION
    // -------------------------------------------------------------
    test('Successful registration', () async {
      // ARRANGE
      // - No users exist in Firebase Auth emulator
      // - No documents exist in users/ collection
      // - Firebase Emulator Suite running

      // Input data
      final email = "test_success@example.com";
      final password = "StrongPassword123";
      final username = "newUser";

      // ACT
      final result = await coordinator.registerUser(
        email: email,
        password: password,
        username: username,
      );

      // ASSERT
      // - Auth account created
      // - Firestore user document exists under users/{uid}
      // - UserModel returned with matching fields
      expect(result.credential.user, isNotNull);

      final uid = result.credential.user!.uid;
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      expect(doc.exists, true);
      expect(doc.data()!['email'], email);
      expect(doc.data()!['username'], username);
      expect(result.user.uid, uid);
      expect(result.user.email, email);
    });

    // -------------------------------------------------------------
    // 2. WEAK PASSWORD ERROR
    // -------------------------------------------------------------
    test('Weak password error', () async {
      // ARRANGE
      // - Auth + Firestore empty
      // - Emulator configured to throw `weak-password`

      // Input data
      final email = "weakpass@example.com";
      final weakPassword = "123"; // guaranteed weak in emulator

      // ACT/ASSERT
      // - Throws RegisterFailure with stage == 'createUser'
      // - code == 'weak-password'

      expect(
        () async => coordinator.registerUser(
          email: email,
          password: weakPassword,
        ),
        throwsA(
          isA<RegisterFailure>()
              .having((e) => e.stage, 'stage', equals('createUser'))
              .having((e) => e.code, 'code', equals('weak-password')),
        ),
      );
    });

    // -------------------------------------------------------------
    // 3. EMAIL ALREADY EXISTS ERROR
    // -------------------------------------------------------------
    test('Email already exists error', () async {
      // ARRANGE
      // - A user with the email already exists in Auth emulator

      final email = "duplicate@example.com";
      final password = "Password123";

      // Create first account
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Input data
      // Attempt to register a second account with the *same* email

      // ACT/ASSERT
      // - Throws RegisterFailure
      // - stage == 'createUser'
      // - code == 'email-already-in-use'

      expect(
        () async => coordinator.registerUser(
          email: email,
          password: "AnotherPassword123",
        ),
        throwsA(
          isA<RegisterFailure>()
              .having((e) => e.stage, 'stage', equals('createUser'))
              .having(
                  (e) => e.code, 'code', equals('email-already-in-use')),
        ),
      );
    });
  });
}