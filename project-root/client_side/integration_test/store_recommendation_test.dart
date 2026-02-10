// integration_test/store_recommendation_test.dart
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

import 'package:what2eat/coordinator/coordinator.dart';

void storeRecommendationTests() {
  final coordinator = Coordinator();

  // Simple helper to make a random-but-deterministic-ish recommendation map
  Map<String, dynamic> _randomRecommendation() {
    const names = [
      'Katsu Den',
      'Spice Garden',
      'Pho Harmony',
      'Sushi Yume',
      'Taco Loco',
    ];
    const reasons = [
      'Highly rated near you with quick service.',
      'Great balance of flavor and value.',
      'Popular choice for group meals.',
      'Consistently fresh and well-reviewed.',
      'Crowd-pleaser with vegetarian options.',
    ];
    const prices = ['$', '$$', '$$–$$$', '$$$'];

    final rnd = Random();
    final name = names[rnd.nextInt(names.length)];
    final reason = reasons[rnd.nextInt(reasons.length)];
    final price = prices[rnd.nextInt(prices.length)];

    // Keep justification to ~1–2 sentences
    final justification = '$reason Perfect for a casual bite.';

    return <String, dynamic>{
      'recommendation': name,
      'justification': justification,
      'priceRange': price,
    };
  }

  group('STORE RECOMMENDATION — Integration Test', () {
    setUp(() async {
      // --- Arrange (suite prep): isolate state ---
      final fs = FirebaseFirestore.instance;
      final roomsSnap = await fs.collection('rooms').get();
      for (final d in roomsSnap.docs) {
        await d.reference.delete();
      }

      final db = FirebaseDatabase.instance;
      await db.ref('participants').remove();
    });

    test('Stores AI recommendation, marks status, and clears RTDB participants', () async {
      // ------------------
      // Arrange
      // ------------------
      final fs = FirebaseFirestore.instance;
      final db = FirebaseDatabase.instance;

      const roomId = 'ROOM_RECO_001';
      // Seed a basic room doc; fields not relevant to assertion are minimal
      await fs.collection('rooms').doc(roomId).set({
        'room_id': roomId,
        'host_uid': 'host_for_reco',
        'output': <String, dynamic>{},
      });

      // Seed RTDB participants so we can verify cleanup
      await db.ref('participants/$roomId/user_a').set({'submitted': true});
      await db.ref('participants/$roomId/user_b').set({'submitted': false});

      final result = _randomRecommendation();

      // ------------------
      // Act
      // ------------------
      final status = await coordinator.storeRecommendation(
        roomId: roomId,
        result: result,
      );

      // ------------------
      // Assert
      // ------------------
      // 1) Return status is "success"
      expect(status, equals('success'));

      // 2) Firestore room doc has aiRecommendation + aiStatus == "done"
      final roomDoc =
          await fs.collection('rooms').doc(roomId).get();
      expect(roomDoc.exists, isTrue);
      final data = roomDoc.data()!;
      expect(data['aiStatus'], equals('done'));
      // Non-deterministic content (we created a random map): must match exactly the input map
      expect(data['aiRecommendation'], equals(result));

      // 3) RTDB participants subtree cleared
      final participantsSnap = await db.ref('participants/$roomId').get();
      expect(participantsSnap.exists, isFalse,
          reason: 'participants/$roomId should be deleted by storeRecommendation');
    });
  });
}