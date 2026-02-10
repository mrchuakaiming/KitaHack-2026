// integration_test/submit_preference_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

import 'package:what2eat/coordinator/coordinator.dart';
import 'package:what2eat/models/preferences.dart';
import 'package:what2eat/models/user.dart';

void submitPreferenceTests() {
  final coordinator = Coordinator();

  Future<DocumentSnapshot<Map<String, dynamic>>?> _findPreferenceDoc(
    String roomId,
    String uid,
  ) async {
    final fs = FirebaseFirestore.instance;

    // Try collection group search first: rooms/*/preferences
    try {
      final groupSnap = await fs
          .collectionGroup('preferences')
          .where('room_id', isEqualTo: roomId)
          .where('uid', isEqualTo: uid)
          .limit(1)
          .get();
      if (groupSnap.docs.isNotEmpty) {
        return groupSnap.docs.first;
      }
    } catch (_) {
      // Not fatal: emulator may not allow group if no index; fall back below.
    }

    // Fallback: top-level "preferences" collection
    final topSnap = await fs
        .collection('preferences')
        .where('room_id', isEqualTo: roomId)
        .where('uid', isEqualTo: uid)
        .limit(1)
        .get();
    if (topSnap.docs.isNotEmpty) {
      return topSnap.docs.first;
    }

    return null;
  }

  group('SUBMIT PREFERENCE — Integration Tests', () {
    setUp(() async {
      // --- Arrange (suite prep): clean relevant data for isolation ---
      final fs = FirebaseFirestore.instance;
      // Clear users
      final usersSnap = await fs.collection('users').get();
      for (final d in usersSnap.docs) {
        await d.reference.delete();
      }
      // Clear rooms (may host subcollection preferences)
      final roomsSnap = await fs.collection('rooms').get();
      for (final d in roomsSnap.docs) {
        await d.reference.delete();
      }
      // Clear top-level preferences (if your service uses that)
      try {
        final prefSnap = await fs.collection('preferences').get();
        for (final d in prefSnap.docs) {
          await d.reference.delete();
        }
      } catch (_) {
        // Ignore if top-level "preferences" doesn't exist.
      }

      // Clear RTDB participants subtree
      final db = FirebaseDatabase.instance;
      await db.ref('participants').remove();
    });

    // -------------------------------------------------------------
    // 1) Submit preferences — all fields filled reasonably
    // -------------------------------------------------------------
    test('Submits full preferences, merges with user defaults, marks RTDB submitted', () async {
      // Arrange
      final fs = FirebaseFirestore.instance;
      final db = FirebaseDatabase.instance;

      const roomId = 'ROOM_PREF_ALL_001';
      const uid = 'user_pref_all';

      // Seed user defaults in Firestore (these will be merged in)
      await fs.collection('users').doc(uid).set({
        'username': 'alice',
        'email': 'alice@example.com',
        'preferred_cuisine': ['japanese'],
        'dietary_restrictions': ['halal'],
      });

      // Build live preferences to submit
      final prefs = PreferencesModel(
        roomId: roomId,
        livePreferences: const [
          {'cuisine': 'thai', 'placeId': 'p1'},
        ],
        preferredCuisine: const ['thai'],
        budget: const [10, 50],
        dietaryRestrictions: const ['vegan'],
      );

      // Act
      final ok = await coordinator.submitPreference(
        uid: uid,
        roomId: roomId,
        preferences: prefs,
      );

      // Assert
      expect(ok, isTrue);

      // 1) Firestore: verify a preferences doc exists for (roomId, uid)
      final doc = await _findPreferenceDoc(roomId, uid);
      expect(doc, isNotNull, reason: 'Should write a preferences document');
      final data = doc!.data()!;

      // Keys from wrapper + model serialization
      expect(data['room_id'], equals(roomId));
      expect(data['uid'], equals(uid));
      expect(data['room_Id'], equals(roomId)); // from PreferencesModel.toJson()

      // Live preferences preserved
      final live = List<Map<String, dynamic>>.from(
        (data['live_preferences'] as List).map((e) => Map<String, dynamic>.from(e)),
      );
      expect(live.length, 1);
      expect(live.first['cuisine'], 'thai');
      expect(live.first['placeId'], 'p1');

      // Budget preserved
      expect(List<int>.from(data['budget'] as List), [10, 50]);

      // Cuisine = union(user.defaults + prefs)
      final cuisines = Set<String>.from((data['preferred_cuisine'] as List).map((e) => e.toString()));
      expect(cuisines.containsAll({'thai', 'japanese'}), isTrue);
      expect(cuisines.length, 2);

      // Dietary = union(user.defaults + prefs)
      final diets = Set<String>.from((data['dietary_restrictions'] as List).map((e) => e.toString()));
      expect(diets.containsAll({'vegan', 'halal'}), isTrue);
      expect(diets.length, 2);

      // 2) RTDB: mark submitted true
      final rtdbSnap = await db.ref('participants/$roomId/$uid').get();
      expect(rtdbSnap.exists, isTrue);
      final rdata = Map<String, dynamic>.from(rtdbSnap.value as Map);
      expect(rdata['submitted'], isTrue);
      expect(rdata.containsKey('disconnected_at'), isFalse);
    });

    // -------------------------------------------------------------
    // 2) Submit preferences — only budget, user has no other prefs
    // -------------------------------------------------------------
    test('Submits only budget; keeps other fields empty; marks RTDB submitted', () async {
      // Arrange
      final fs = FirebaseFirestore.instance;
      final db = FirebaseDatabase.instance;

      const roomId = 'ROOM_PREF_BUDGET_001';
      const uid = 'user_budget_only';

      // Either create an empty user doc or skip; Coordinator handles null as empty.
      await fs.collection('users').doc(uid).set({
        'username': 'bob',
        'email': 'bob@example.com',
        'preferred_cuisine': <String>[],
        'dietary_restrictions': <String>[],
      });

      final prefs = PreferencesModel(
        roomId: roomId,
        livePreferences: const [],
        preferredCuisine: const [],
        budget: const [0, 100],
        dietaryRestrictions: const [],
      );

      // Act
      final ok = await coordinator.submitPreference(
        uid: uid,
        roomId: roomId,
        preferences: prefs,
      );

      // Assert
      expect(ok, isTrue);

      // Firestore: verify doc exists and fields are as expected
      final doc = await _findPreferenceDoc(roomId, uid);
      expect(doc, isNotNull);
      final data = doc!.data()!;

      expect(data['room_id'], equals(roomId));
      expect(data['uid'], equals(uid));
      expect(data['room_Id'], equals(roomId));

      // Empty arrays preserved
      expect((data['live_preferences'] as List).isEmpty, isTrue);
      expect((data['preferred_cuisine'] as List).isEmpty, isTrue);
      expect((data['dietary_restrictions'] as List).isEmpty, isTrue);
      // Budget preserved
      expect(List<int>.from(data['budget'] as List), [0, 100]);

      // RTDB submitted flag
      final rtdbSnap = await db.ref('participants/$roomId/$uid').get();
      expect(rtdbSnap.exists, isTrue);
      final rdata = Map<String, dynamic>.from(rtdbSnap.value as Map);
      expect(rdata['submitted'], isTrue);
      expect(rdata.containsKey('disconnected_at'), isFalse);
    });
  });
}