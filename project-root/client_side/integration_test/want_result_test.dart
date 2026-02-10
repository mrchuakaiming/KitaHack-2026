// integration_test/want_result_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:what2eat/coordinator/coordinator.dart';

void wantResultTests() {
  final coordinator = Coordinator();

  group('WANT RESULT — Integration Tests', () {
    setUp(() async {
      // --- Arrange (suite prep): isolate tests ---
      final fs = FirebaseFirestore.instance;

      // Clear rooms collection to avoid leakage across tests
      final roomsSnap = await fs.collection('rooms').get();
      for (final d in roomsSnap.docs) {
        await d.reference.delete();
      }
    });

    // -------------------------------------------------------------
    // 1) Result obtained successfully (happy path)
    // -------------------------------------------------------------
    test('Returns output map when room exists and output is present', () async {
      // Arrange
      final fs = FirebaseFirestore.instance;
      const roomId = 'ROOM_OUTPUT_OK_001';
      final output = <String, dynamic>{
        'placeId': 'abc123',
        'name': 'Spice Garden',
        'address': '123 Market St',
      };

      await fs.collection('rooms').doc(roomId).set({
        'room_id': roomId,
        'host_uid': 'host_uid_ok',
        'output': output, // critical field
      });

      // Act
      final result = await coordinator.wantResult(roomId: roomId);

      // Assert
      expect(result, isA<Map<String, dynamic>>());
      expect(result, equals(output)); // must match exactly what was stored
    });

    // -------------------------------------------------------------
    // 2) Room does not exist
    // -------------------------------------------------------------
    test('Throws room-not-found if room document is missing', () async {
      // Arrange
      const missingRoom = 'ROOM_MISSING_999';

      // Act & Assert
      await expectLater(
        () => coordinator.wantResult(roomId: missingRoom),
        throwsA(
          isA<StateError>().having(
            (e) => e.toString(),
            'message',
            contains('room-not-found'),
          ),
        ),
      );
    });

    // -------------------------------------------------------------
    // 3) Room exists but output not yet created
    // -------------------------------------------------------------
    test('Throws output-not-found if output is missing or not a Map', () async {
      // Arrange
      final fs = FirebaseFirestore.instance;
      const roomId = 'ROOM_OUTPUT_EMPTY_001';

      // Create room with no output field
      await fs.collection('rooms').doc(roomId).set({
        'room_id': roomId,
        'host_uid': 'host_uid_empty',
        // 'output' intentionally absent OR could be set to a non-map (e.g., string)
      });

      // Act & Assert
      await expectLater(
        () => coordinator.wantResult(roomId: roomId),
        throwsA(
          isA<StateError>().having(
            (e) => e.toString(),
            'message',
            contains('output-not-found'),
          ),
        ),
      );
    });
  });
}