// integration_test/delete_account_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:what2eat/coordinators/coordinator.dart';

void deleteAccountTests() {
  final coordinator = Coordinator();

  group('DELETE ACCOUNT — Integration Tests', () {
    setUp(() async {
      // --- Arrange (suite prep): isolate tests ---
      final fs = FirebaseFirestore.instance;
      // Clean users collection
      final users = await fs.collection('users').get();
      for (final d in users.docs) {
        await d.reference.delete();
      }
      // Ensure signed-out
      await FirebaseAuth.instance.signOut();
    });

    // -------------------------------------------------------------
    // 1) Account deleted successfully
    // -------------------------------------------------------------
    test('Deletes Firestore user doc and Auth account', () async {
      // ------------------
      // Arrange
      // ------------------
      final auth = FirebaseAuth.instance;
      final fs = FirebaseFirestore.instance;

      final email = 'delete_me@example.com';
      final password = 'DeletePass123!';

      // Create & sign in a fresh user in the Auth emulator
      final cred = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = cred.user!.uid;

      // Seed a Firestore user document to be deleted by clearData(uid)
      await fs.collection('users').doc(uid).set({
        'username': 'to_be_deleted',
        'email': email,
        'dietary_restrictions': <String>[],
        'preferred_cuisine': <String>[],
      });

      // Safety: ensure the user is indeed current (recent login semantics)
      expect(auth.currentUser, isNotNull);
      expect(auth.currentUser!.uid, equals(uid));

      // ------------------
      // Act
      // ------------------
      await coordinator.deleteAccount();

      // ------------------
      // Assert
      // ------------------
      // Firestore doc deleted
      final userDoc = await fs.collection('users').doc(uid).get();
      expect(userDoc.exists, isFalse, reason: 'User doc should be removed');

      // Auth user deleted (no current user)
      expect(auth.currentUser, isNull,
          reason: 'Auth currentUser should be null after deletion');
    });

    // -------------------------------------------------------------
    // 2) User is not logged in
    // -------------------------------------------------------------
    test('Throws when no authenticated user is present', () async {
      // ------------------
      // Arrange
      // ------------------
      final auth = FirebaseAuth.instance;
      await auth.signOut(); // Ensure no user is signed in

      // ------------------
      // Act & Assert
      // ------------------
      await expectLater(
        () => coordinator.deleteAccount(),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('No authenticated user.'),
          ),
        ),
      );
    });
  });
}
