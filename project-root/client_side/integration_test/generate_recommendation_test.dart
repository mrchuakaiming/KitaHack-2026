import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

import 'package:what2eat/coordinators/coordinator.dart';

void generateRecommendationTests() {
  final coordinator = Coordinator();
  group('generateRecommendation integration', () {
    const roomId = 'testRoom';

    setUpAll(() async {
      // Clear Firestore and RTDB before tests
      final firestore = FirebaseFirestore.instance;
      final rtdb = FirebaseDatabase.instance;

      await firestore.collection('rooms').doc(roomId).delete().catchError((_) {});
      await rtdb.ref('rooms/$roomId').remove();
    });

    test('returns AI recommendation with preferences', () async {
      // 1️⃣ Setup Firestore with preferences
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('rooms').doc(roomId).set({
        'preferences': [
          {
            'roomId': roomId,
            'livePreferences': [
              {'restaurant': 'p1', 'cuisine': 'Italian'}
            ],
            'preferredCuisine': ['Italian'],
            'budget': [10, 50],
            'dietaryRestrictions': []
          }
        ]
      });

      // 2️⃣ Call generateRecommendation
      final result = await coordinator.generateRecommendation(roomId: roomId);

      // 3️⃣ Validate structure of result
      expect(result, isA<Map<String, String>>());
      expect(result.containsKey('recommended_place_id'), true);
      expect(result.containsKey('recommended_cuisine'), true);
      expect(result.containsKey('justification'), true);
    });

    test('throws when no preferences exist', () async {
      const emptyRoomId = 'emptyRoom';
      await FirebaseFirestore.instance.collection('rooms').doc(emptyRoomId).delete().catchError((_) {});

      await expectLater(
        () => coordinator.generateRecommendation(roomId: emptyRoomId),
        throwsA(predicate((e) => e.toString().contains('No preferences submitted')))
      );
    });
  });
}
