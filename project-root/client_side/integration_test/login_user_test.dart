// integration_test/login_user_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:what2eat/coordinator/coordinator.dart';

/// Call this from test_main.dart
void loginUserTests() {
  final coordinator = Coordinator();

  group('LOGIN USER — Integration Tests', () {
    setUp(() async {
      // --- Arrange (suite prep): ensure emulators + clean slate ---
      // Connectors are already set in test_main.setUpAll, but we keep tests isolated.
      await FirebaseAuth.instance.signOut();

      // Clean Firestore "users" collection to avoid cross-test leakage
      final fs = FirebaseFirestore.instance;
      final usersSnap = await fs.collection('users').get();
      for (final d in usersSnap.docs) {
        await d.reference.delete();
      }

      // Clear any currently signed-in user (Auth emulator keeps state per process)
      final current = FirebaseAuth.instance.currentUser;
      if (current != null) {
        try {
          await current.delete();
        } catch (_) {
          // Ignore if recent-login required; signOut is enough for our tests.
        }
      }
    });

    // -------------------------------------------------------------
    // 1) Successful login
    // -------------------------------------------------------------
    test('Successful login', () async {
      // Arrange
      final email = 'login_success@example.com';
      final password = 'LoginPass123!';

      // Create the user in Auth emulator
      final created = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      final uid = created.user!.uid;

      // Seed Firestore user doc similar to registration flow would do
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'username': 'existingUser',
        'email': email,
        'dietary_restrictions': <String>[],
        'preferred_cuisine': <String>[],
      });

      // Act
      final result = await coordinator.logIn(email: email, password: password);

      // Assert
      expect(result.credential.user, isNotNull);
      expect(result.credential.user!.uid, equals(uid));
      expect(result.user.uid, equals(uid));
      expect(result.user.email, equals(email));
      // hostedRooms can be empty; just ensure it's a list
      expect(result.user.hostedRooms, isA<List<String>>());
    });

    // -------------------------------------------------------------
    // 2) Non-existent user
    // -------------------------------------------------------------
    test('Non-existent user throws user-not-found', () async {
      // Arrange
      final email = 'nouser@example.com';
      final password = 'DoesNotMatter1!';

      // Act & Assert
      await expectLater(
        () => coordinator.logIn(email: email, password: password),
        throwsA(
          isA<RegisterFailure>()
              .having((e) => e.stage, 'stage', 'logIn')
              .having((e) => e.code, 'code', 'user-not-found'),
        ),
      );
    });

    // -------------------------------------------------------------
    // 3) Incorrect password
    // -------------------------------------------------------------
    test('Incorrect password throws wrong-password', () async {
      // Arrange
      final email = 'wrongpass@example.com';
      final correctPassword = 'RightPass123!';
      final attemptedPassword = 'WrongPass!';

      // Create the user with the correct password
      await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: correctPassword);

      // Act & Assert
      await expectLater(
        () => coordinator.logIn(email: email, password: attemptedPassword),
        throwsA(
          isA<RegisterFailure>()
              .having((e) => e.stage, 'stage', 'logIn')
              .having((e) => e.code, 'code', 'wrong-password'),
        ),
      );
    });
  });
}