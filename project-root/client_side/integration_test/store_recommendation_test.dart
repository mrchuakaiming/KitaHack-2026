// integration_test/store_recommendation_test.dart

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

import 'package:what2eat/coordinators/coordinator.dart';

/// This function is called by the global test runner (test_main.dart)
void storeRecommendationTests() {
  // Coordinator instance (uses Firebase initialized by runner)
  final coordinator = Coordinator();

  // Helper to generate a random recommendation map
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

    const prices = ['Free', r'$', r'$$', r'$$$'];

    final rnd = Random();
    final name = names[rnd.nextInt(names.length)];
    final reason = reasons[rnd.nextInt(reasons.length)];
    final price = prices[rnd.nextInt(prices.length)];

    return <String, dynamic>{
      'recommendation': name,
      'justification': '$reason Perfect for a casual bite.',
      'priceRange': price,
    };
  }

  group('STORE RECOMMENDATION — Integration Test', () {
    setUp(() async {
      // Clean Firestore rooms collection
      final fs = FirebaseFirestore.instance;
      final roomsSnap = await fs.collection('rooms').get();
      for (final doc in roomsSnap.docs) {
        await doc.reference.delete();
      }

      // Clean RTDB participants subtree
      final db = FirebaseDatabase.instance;
      await db.ref('participants').remove();
    });

    testWidgets(
      'Stores AI recommendation and clears RTDB participants',
      (tester) async {
        final fs = FirebaseFirestore.instance;
        final db = FirebaseDatabase.instance;

        const roomId = 'ROOM_RECO_001';

        // Seed Firestore room doc
        await fs.collection('rooms').doc(roomId).set({
          'room_id': roomId,
          'host_uid': 'host_for_reco',
          'output': <String, dynamic>{},
        });

        // Seed RTDB participants
        await db.ref('participants/$roomId/user_a')
            .set({'submitted': true});
        await db.ref('participants/$roomId/user_b')
            .set({'submitted': false});

        final result = _randomRecommendation();

        // ------------------ Act ------------------
        final status = await coordinator.storeRecommendation(
          roomId: roomId,
          result: result,
        );

        // ------------------ Assert ------------------
        expect(status, equals('success'));

        final roomDoc = await fs.collection('rooms').doc(roomId).get();
        expect(roomDoc.exists, isTrue);

        final data = roomDoc.data()!;
        expect(data.containsKey('output'), isTrue);

        final output = data['output'] as Map<String, dynamic>;
        expect(output['suggestion'], equals(result['recommendation']));
        expect(output['justification'], equals(result['justification']));
        expect(output['price_range'], equals(result['priceRange']));

        expect(data.containsKey('aiStatus'), isFalse);
        expect(data.containsKey('aiRecommendation'), isFalse);

        final participantsSnap = await db.ref('participants/$roomId').get();
        expect(
          participantsSnap.exists,
          isFalse,
          reason: 'participants/$roomId should be deleted by storeRecommendation',
        );
      },
    );
  });
}
